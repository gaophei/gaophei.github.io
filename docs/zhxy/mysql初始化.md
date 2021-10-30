##mysql初始化账户、库

```mysql
set global validate_password.policy=0;
set global validate_password.length=1;

create user 'admin_center'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'agent_service'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'cas_server'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'fileupload'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'formflow'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'message'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'platform_openapi'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'tmp_data'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'token_server'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'ttc'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'user'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'user_authz'@'%' identified with mysql_native_password  by 'xg@sufe1917';
create user 'portal_service'@'%' identified with mysql_native_password  by 'xg@sufe1917';

  create database `user` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  create database `user_authz` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  create database `cas_server` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  create database `token_server` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  create database `agent_service` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  create database `tmp_data` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database `portal_service` DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
  
create database admin_center      DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database fileupload        DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database formflow          DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database message           DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database platform_openapi  DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database sys               DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
create database ttc               DEFAULT CHARSET utf8 COLLATE utf8_general_ci;

  grant all privileges on `user`.* to 'user'@'%' with grant option;
  grant all privileges on `user_authz`.* to 'user_authz'@'%' with grant option;
  grant all privileges on `cas_server`.* to 'cas_server'@'%' with grant option;
  grant all privileges on `token_server`.* to 'token_server'@'%' with grant option;
  grant all privileges on `agent_service`.* to 'agent_service'@'%' with grant option;
  grant all privileges on `tmp_data`.* to 'tmp_data'@'%' with grant option;
  grant all privileges on `admin_center`.* to 'admin_center'@'%' with grant option;
grant all privileges on `fileupload`.* to 'fileupload'@'%' with grant option;
grant all privileges on `formflow`.* to 'formflow'@'%' with grant option;
grant all privileges on `message`.* to 'message'@'%' with grant option;
grant all privileges on `platform_openapi`.* to 'platform_openapi'@'%' with grant option;
grant all privileges on `ttc`.* to 'ttc'@'%' with grant option;
grant all privileges on `portal_service`.* to 'portal_service'@'%' with grant option;

  grant SUPER on *.* to 'user'@'%';
  grant SUPER on *.* to 'user_authz'@'%';
  grant SUPER on *.* to 'cas_server'@'%';
  grant SUPER on *.* to 'tmp_data'@'%';
  grant SUPER on *.* to 'formflow'@'%';
  grant SUPER on *.* to 'ttc'@'%';
  grant SUPER on *.* to 'fileupload'@'%';

```

