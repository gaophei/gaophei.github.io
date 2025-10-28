
-- 建议把 BCT 文件放在数据库数据盘，不要放在备份/FRA 目录
-- 修改 DB_UNIQUE_NAME 与路径后执行
-- 注意：如果已启用 BCT，可先禁用再修改路径

-- 检查：
-- SELECT status, filename FROM v$block_change_tracking;

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
USING FILE '/u02/oradata/orcl/bct_orcl.chg';
