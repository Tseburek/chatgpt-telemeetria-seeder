-- queries.sql
-- Kasulikud SELECT päringud ChatGPT telemeetria skeemile

/* 1) Päevaaktiivsed kasutajad (DAU) viimase 14 päeva kohta. */
SELECT
  DATE(m.created_at)                AS day,
  COUNT(DISTINCT m.author_user_id)  AS active_users
FROM message m
WHERE m.role = 'user'
  AND m.created_at >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
GROUP BY DATE(m.created_at)
ORDER BY day DESC;

/* 2) Mudelite kasutuse raport viimase 30 päeva kohta. (LEFT JOIN, aggregatsioon) */
SELECT
  mo.name                           AS model,
  mo.provider                       AS provider,
  COUNT(m.id)                       AS messages,
  ROUND(AVG(m.latency_ms), 0)       AS avg_latency_ms,
  ROUND(AVG(m.token_in + m.token_out), 1) AS avg_tokens_total
FROM model mo
LEFT JOIN conversation c ON c.model_id = mo.id
LEFT JOIN message m       ON m.conversation_id = c.id
                          AND m.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY mo.id, mo.name, mo.provider
ORDER BY messages DESC, model ASC;

/* 3) Riikide edetabel: aktiivsed kasutajad ja sõnumid (INNER JOIN + HAVING). */
SELECT
  u.country                         AS country,
  COUNT(DISTINCT u.id)              AS users,
  COUNT(m.id)                       AS messages
FROM user u
JOIN conversation c ON c.user_id = u.id
JOIN message m      ON m.conversation_id = c.id
WHERE m.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY u.country
HAVING messages > 1000
ORDER BY messages DESC
LIMIT 20;

/* 4) Power-userid: >100 sõnumit viimase 30 päeva jooksul (JOIN 3 tabelit + HAVING). */
SELECT
  u.id,
  u.full_name                       AS user_name,
  u.email,
  COUNT(m.id)                       AS user_messages_30d,
  MAX(m.created_at)                 AS last_activity
FROM user u
JOIN conversation c ON c.user_id = u.id
JOIN message m      ON m.conversation_id = c.id AND m.role = 'user'
WHERE m.created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY u.id, u.full_name, u.email
HAVING user_messages_30d > 100
ORDER BY user_messages_30d DESC, last_activity DESC
LIMIT 50;

/* 5) Vestluse keskmine latentsus (JOIN 4 tabelit, GROUP BY, ORDER BY, LIMIT). */
SELECT
  c.id                               AS conversation_id,
  u.full_name                        AS user_name,
  mo.name                            AS model,
  ROUND(AVG(m.latency_ms), 0)        AS avg_latency_ms,
  MAX(m.created_at)                  AS last_msg_at
FROM conversation c
JOIN user u   ON u.id = c.user_id
JOIN model mo ON mo.id = c.model_id
JOIN message m ON m.conversation_id = c.id
WHERE m.created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY c.id, u.full_name, mo.name
ORDER BY avg_latency_ms DESC
LIMIT 20;

/* 6) Vestluse viimased 10 sõnumit (WHERE + ORDER BY + LIMIT; valime ainult vajalikud veerud).
   NB: asenda :conv_id konkreetse vestluse ID-ga.
*/
SELECT
  m.id                      AS message_id,
  m.role,
  COALESCE(u.full_name, 'assistant') AS author,
  LEFT(m.content, 200)      AS content_preview,
  m.token_in,
  m.token_out,
  m.created_at
FROM message m
LEFT JOIN user u ON u.id = m.author_user_id
WHERE m.conversation_id = :conv_id
ORDER BY m.created_at DESC
LIMIT 10;
