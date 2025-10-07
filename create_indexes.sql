USE chatgpt_telemetry;

-- Secondary/analytic indexes restored after bulk load
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
