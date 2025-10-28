
-- 修改下方本地路径以匹配你的实际目录
-- RAC: CLUSTER=N + 本地磁盘，不依赖共享存储
-- 确保该路径在将要运行 expdp 的节点上存在并可写
CREATE OR REPLACE DIRECTORY DP_DIR AS '/backup/orcl/expdp';
GRANT READ, WRITE ON DIRECTORY DP_DIR TO SYSTEM;
-- 如使用专用备份账号，将 SYSTEM 替换为该用户
