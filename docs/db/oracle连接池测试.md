下面给出几种常见语言／框架的最小可运行示例，帮你**用连接池**验证刚刚启动的 Oracle 11g XE 容器（`wnameless/oracle-xe-11g-r2`）是否能正常接入。

------

## 0 准备工作

| 项目         | 默认值（镜像内置）                        |
| ------------ | ----------------------------------------- |
| 监听地址     | `1521/tcp`（已映射到宿主）                |
| Service Name | `XE`                                      |
| SID          | `XE`                                      |
| 用户/口令    | `system / oracle``sys / oracle as sysdba` |

1. **确保数据库已完全启动**

   ```bash
   docker logs -f oracle11g | grep -i "DATABASE IS READY"
   ```

   出现 `DATABASE IS READY TO USE!` 后再做后续测试，否则会因启动过程耗时而误判连接失败。

2. **宿主机防火墙**确认 1521 端口未被阻断。

------

## 1 Java（HikariCP）快速测试

> 适合裸 Java 或 Spring 之外的小脚本测试。

**依赖（Maven）**

```xml
<dependency>
  <groupId>com.zaxxer</groupId>
  <artifactId>HikariCP</artifactId>
  <version>5.1.0</version>
</dependency>
<!-- Oracle JDBC：将 ojdbc8.jar 手动放进本地仓库或使用官方 GAV -->
<dependency>
  <groupId>com.oracle.database.jdbc</groupId>
  <artifactId>ojdbc8</artifactId>
  <version>21.12.0.0</version>
</dependency>
```

**示例代码**

```java
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

public class OraclePoolPing {
    public static void main(String[] args) throws Exception {
        HikariConfig cfg = new HikariConfig();
        cfg.setJdbcUrl("jdbc:oracle:thin:@//127.0.0.1:1521/XE"); // Service 名写 XE
        cfg.setUsername("system");
        cfg.setPassword("oracle");
        cfg.setMaximumPoolSize(5);
        cfg.setConnectionTimeout(10_000);          // 10 秒
        cfg.setValidationTimeout(3_000);           // 心跳 3 秒
        cfg.setConnectionTestQuery("SELECT 1 FROM dual");

        try (HikariDataSource ds = new HikariDataSource(cfg);
             Connection conn = ds.getConnection();
             PreparedStatement ps = conn.prepareStatement("SELECT SYSDATE FROM dual");
             ResultSet rs = ps.executeQuery()) {

            if (rs.next()) {
                System.out.println("Oracle ping ok, SYSDATE = " + rs.getString(1));
            }
        }
    }
}
```

运行后看到形如 `Oracle ping ok, SYSDATE = 2025-07-08 14:32:11` 即证明连接池创建成功并能取得连接。

------

## 2 Spring Boot（Hikari 自动集成）

在 `application.yml` 里直接写：

```yaml
spring:
  datasource:
    hikari:
      jdbc-url: jdbc:oracle:thin:@//localhost:1521/XE
      username: system
      password: oracle
      minimum-idle: 1
      maximum-pool-size: 5
      connection-timeout: 10000
      connection-test-query: SELECT 1 FROM dual
```

然后启动 Spring Boot，日志中会出现：

```
com.zaxxer.hikari.HikariDataSource     : HikariPool-1 - Starting...
com.zaxxer.hikari.HikariDataSource     : HikariPool-1 - Start completed.
```

若配置错误，会在 10 秒左右抛出连接超时异常。

------

## 3 Python（`oracledb` 轻量驱动 & 会话池）

```bash
pip install oracledb --upgrade
```
```python
import oracledb
#oracledb.init_oracle_client()  # 若系统中已安装 Oracle Instant Client，可省略

pool = oracledb.SessionPool(user="system",
                            password="oracle",
                            dsn="127.0.0.1:1521/XE",
                            min=1, max=4, increment=1,
                            encoding="UTF-8")

with pool.acquire() as conn:
    with conn.cursor() as cur:
        cur.execute("select 'OK', sysdate from dual")
        print(cur.fetchone())
```

输出 `('OK', datetime.datetime(2025, 7, 8, 14, 32, 20))` 表示连接正常。

------

## 4 Go （`database/sql` 原生池）

```go
import (
    "context"
    "database/sql"
    _ "github.com/godror/godror"
    "log"
    "time"
)

func main() {
    db, err := sql.Open("godror", `user="system" password="oracle" connectString="localhost:1521/XE"`)
    if err != nil { log.Fatal(err) }
    db.SetMaxIdleConns(1)
    db.SetMaxOpenConns(5)
    db.SetConnMaxLifetime(time.Hour)

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    var now string
    if err := db.QueryRowContext(ctx, "SELECT TO_CHAR(sysdate,'YYYY-MM-DD HH24:MI:SS') FROM dual").Scan(&now); err != nil {
        log.Fatal("ping failed:", err)
    }
    log.Println("Oracle ping ok, time:", now)
}
```

------

## 故障排查速查表

| 现象                                                         | 排查方向                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `ORA-12514: TNS: listener does not currently know of service requested` | Service Name 写错，应为 `XE`；或者容器还在启动               |
| `java.sql.SQLRecoverableException: IO Error: The Network Adapter could not establish the connection` | 容器未启动完或 1521 端口被防火墙拦截                         |
| `ORA-01017: invalid username/password`                       | 默认帐号已改过密码，`docker exec -it oracle11g bash` 里用 `sqlplus / as sysdba` 修改或建新用户 |

------

### 一句话总结

- 端口映射 `-p 1521:1521` 足以本机直连；
- 连接字符串统一使用 `jdbc:oracle:thin:@//127.0.0.1:1521/XE`（或 `host.docker.internal`）；
- 各语言连接池核心只需 **验证 SQL**（`SELECT 1 FROM dual`）+ **适当的超时设置**。

照着上述任一示例跑通，你就完成了通过连接池对容器化 Oracle 实例的连接验证。祝测试顺利!