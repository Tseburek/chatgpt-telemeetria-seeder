import 'dotenv/config';
import mysql from 'mysql2/promise';
import { faker } from '@faker-js/faker';

// ---- config ----
const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = Number(process.env.DB_PORT || 3306);
const DB_USER = process.env.DB_USER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || '';
const DB_NAME = process.env.DB_NAME || 'chatgpt_telemetry';

const USERS = Number(process.env.USERS || 100_000);
const CONVERSATIONS = Number(process.env.CONVERSATIONS || 300_000);
const MESSAGES = Number(process.env.MESSAGES || 2_000_000);
const BATCH_SIZE = Number(process.env.BATCH_SIZE || 5_000);
const SEED = Number(process.env.SEED || 424242);

// reproducible faker
faker.seed(SEED);

function randInt(min: number, max: number) {
  return Math.floor(faker.number.int({min, max}));
}

function randomDateWithinDays(days: number) {
  const now = new Date();
  const past = new Date(now.getTime() - days*24*60*60*1000);
  return faker.date.between({from: past, to: now});
}

async function main() {
  const conn = await mysql.createConnection({
    host: DB_HOST, port: DB_PORT, user: DB_USER, password: DB_PASSWORD, database: DB_NAME,
    multipleStatements: true, charset: 'utf8mb4'
  });
  console.log('Connected.');

  // Speed up large inserts
  await conn.query('SET FOREIGN_KEY_CHECKS=0');
  await conn.query("SET SESSION sql_log_bin=0"); // avoid binlog overhead when possible
  await conn.query("SET SESSION unique_checks=0, SESSION autocommit=0");

  // Seed lookup tables
  console.log('Seeding lookup tables...');
  const locales = [
    ['en-US','English (US)'],
    ['et-EE','Eesti'],
    ['fi-FI','Suomi'],
    ['de-DE','Deutsch'],
    ['fr-FR','Français'],
    ['es-ES','Español']
  ];
  await conn.query('DELETE FROM locale');
  await conn.query('INSERT INTO locale(code, name) VALUES ' + locales.map(()=>'(?,?)').join(','), locales.flat());

  const models = [
    ['gpt-3.5-turbo','OpenAI'],
    ['gpt-4o','OpenAI'],
    ['gpt-4o-mini','OpenAI'],
    ['claude-3.5-sonnet','Anthropic'],
    ['llama-3.1-70b','Meta']
  ];
  await conn.query('DELETE FROM model');
  await conn.query('INSERT INTO model(name, provider) VALUES ' + models.map(()=>'(?,?)').join(','), models.flat());

  // USERS
  console.log(`Seeding users: ${USERS}`);
  await conn.query('DELETE FROM user');
  for (let i=0;i<USERS;i+=BATCH_SIZE) {
    const rows:number = Math.min(BATCH_SIZE, USERS - i);
    const params:any[] = [];
    const values = [];
    for (let j=0;j<rows;j++) {
      const full = faker.person.fullName();
      const email = faker.internet.email({firstName: faker.person.firstName(), lastName: faker.person.lastName()}).toLowerCase();
      const country = faker.location.countryCode('alpha-2');
      const locale_id = randInt(1, locales.length);
      const created_at = randomDateWithinDays(365);
      params.push(full, email, country, locale_id, created_at);
      values.push('(?,?,?,?,?)');
    }
    const sql = 'INSERT INTO user(full_name, email, country, locale_id, created_at) VALUES ' + values.join(',');
    await conn.query(sql, params);
    if (i % (BATCH_SIZE*10) === 0) console.log(`  users -> ${Math.min(i+rows, USERS)}/${USERS}`);
  }

  // CONVERSATIONS
  console.log(`Seeding conversations: ${CONVERSATIONS}`);
  await conn.query('DELETE FROM conversation');
  for (let i=0;i<CONVERSATIONS;i+=BATCH_SIZE) {
    const rows:number = Math.min(BATCH_SIZE, CONVERSATIONS - i);
    const params:any[] = [];
    const values = [];
    for (let j=0;j<rows;j++) {
      const user_id = randInt(1, USERS);
      const title = faker.lorem.sentence({min:3, max:7});
      const model_id = randInt(1, models.length);
      const created_at = randomDateWithinDays(365);
      params.push(user_id, title, model_id, created_at);
      values.push('(?,?,?,?)');
    }
    const sql = 'INSERT INTO conversation(user_id, title, model_id, created_at) VALUES ' + values.join(',');
    await conn.query(sql, params);
    if (i % (BATCH_SIZE*10) === 0) console.log(`  conv -> ${Math.min(i+rows, CONVERSATIONS)}/${CONVERSATIONS}`);
  }

  // MESSAGES (≥ 2,000,000)
  console.log(`Seeding messages: ${MESSAGES}`);
  await conn.query('DELETE FROM message');

  for (let i=0;i<MESSAGES;i+=BATCH_SIZE) {
    const rows:number = Math.min(BATCH_SIZE, MESSAGES - i);
    const params:any[] = [];
    const values = [];
    for (let j=0;j<rows;j++) {
      const conversation_id = randInt(1, CONVERSATIONS);
      const role = Math.random() < 0.5 ? 'user' : 'assistant';
      const author_user_id = role === 'user' ? randInt(1, USERS) : null;
      const content = role === 'user' ? faker.lorem.sentences({min:1,max:3}) : faker.lorem.sentences({min:1,max:4});
      const token_in = role === 'user' ? randInt(5, 200) : randInt(50, 400);
      const token_out = role === 'assistant' ? randInt(50, 800) : 0;
      const latency_ms = randInt(100, 8000);
      const created_at = randomDateWithinDays(365);
      params.push(conversation_id, role, author_user_id, content, token_in, token_out, latency_ms, created_at);
      values.push('(?,?,?,?,?,?,?,?)');
    }
    const sql = 'INSERT INTO message(conversation_id, role, author_user_id, content, token_in, token_out, latency_ms, created_at) VALUES ' + values.join(',');
    await conn.query(sql, params);
    if (i % (BATCH_SIZE*10) === 0) console.log(`  msgs -> ${Math.min(i+rows, MESSAGES)}/${MESSAGES}`);
  }

  // restore settings & indexes
  await conn.query('SET FOREIGN_KEY_CHECKS=1');
  await conn.query('SET SESSION unique_checks=1, SESSION autocommit=1');

  console.log('Creating secondary indexes...');
  const indexSql = `
    ALTER TABLE user
      ADD INDEX idx_user_created_at (created_at),
      ADD INDEX idx_user_country (country);
    ALTER TABLE conversation
      ADD INDEX idx_conv_user_id_created (user_id, created_at),
      ADD INDEX idx_conv_model_id (model_id);
    ALTER TABLE message
      ADD INDEX idx_msg_conv_created (conversation_id, created_at),
      ADD INDEX idx_msg_role (role),
      ADD INDEX idx_msg_author (author_user_id);
  `;
  await conn.query(indexSql);

  await conn.end();
  console.log('Done ✅');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
