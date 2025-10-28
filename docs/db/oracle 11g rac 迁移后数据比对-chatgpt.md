下面给你一套**可直接落地**的校验方案，按“由快到严”分三层：
 A. 快速“烟囱式”核对（对象数、行数概览） → B. 精确行数与主键集合一致性 → C. 全量逐行逐列比对（`DBMS_COMPARISON`）。
 示例均以**目标单实例**连回**源RAC**做对比（通过 DB Link）。

------

# 0）准备：建立对比专用 DB Link

> 用一个只读账号即可（需能查业务 schema 的表）。

**源库（RAC）**：

```sql
create user CMP identified by "Cmp#2025";
grant create session to CMP;
grant select any table to CMP; -- 或按需对各业务schema逐一授予select
grant select_catalog_role to CMP;
```

**目标库（单实例）**（`tnsnames.ora` 中有 `RACDB` 别名）：

```sql
create database link SRC connect to CMP identified by "Cmp#2025" using 'RACDB';
```

> 后续所有 `@SRC` 都表示“去源库查询”。

------

# A. 快速核对（分钟级）

## A1. 各业务 schema 的表数量是否一致

```sql
-- 目标 vs 源 的表数量（排除系统schema）
with tgt as (
  select owner, count(*) tab_cnt from dba_tables
  where owner not in ('SYS','SYSTEM','SYSMAN','MDSYS','XDB','OUTLN','ORDSYS')
  group by owner
),
src as (
  select owner, count(*) tab_cnt from dba_tables@SRC
  where owner not in ('SYS','SYSTEM','SYSMAN','MDSYS','XDB','OUTLN','ORDSYS')
  group by owner
)
select coalesce(t.owner, s.owner) owner,
       s.tab_cnt src_tabs, t.tab_cnt tgt_tabs,
       case when s.tab_cnt = t.tab_cnt then 'OK' else 'DIFF' end status
from tgt t full join src s on s.owner=t.owner
order by 1;
```

## A2. “统计信息行数”对比（很快，但依赖统计信息是否新）

> 若你刚导入，先在**目标库**收集一次业务 schema 统计信息：

```sql
begin
  dbms_stats.gather_schema_stats('APP1', options=>'GATHER AUTO', cascade=>true);
  dbms_stats.gather_schema_stats('APP2', options=>'GATHER AUTO', cascade=>true);
end;
/
```

对比 `DBA_TABLES.NUM_ROWS`：

```sql
with s as (
  select owner, table_name, num_rows from dba_tables@SRC
  where owner in ('APP1','APP2') and temporary='N'
),
t as (
  select owner, table_name, num_rows from dba_tables
  where owner in ('APP1','APP2') and temporary='N'
)
select coalesce(s.owner,t.owner) owner, coalesce(s.table_name,t.table_name) table_name,
       s.num_rows src_rows, t.num_rows tgt_rows,
       case when s.num_rows=t.num_rows then 'OK' else 'DIFF' end as status
from s full join t using(owner, table_name)
where nvl(s.num_rows,-1) <> nvl(t.num_rows,-1)
order by owner, table_name;
```

> **提示**：这一步只是“红黄灯”，不等于精确行数一致（统计信息可能滞后）。

------

# B. 精确核对（强一致）

## B1. 精确行数（逐表 `count(*)`）

> 下面 PL/SQL 会对 `APP1, APP2` 的所有**非临时表**做精确行数对比，输出差异。

```sql
set serveroutput on size unlimited
declare
  l_link constant varchar2(30) := 'SRC';
  l_src  number;
  l_tgt  number;
begin
  for r in (
    select owner, table_name
      from dba_tables
     where owner in ('APP1','APP2')
       and temporary='N'
  ) loop
    begin
      execute immediate 'select /*+ parallel(4) */ count(*) from '||
                        r.owner||'.'||r.table_name||'@'||l_link into l_src;
      execute immediate 'select /*+ parallel(4) */ count(*) from '||
                        r.owner||'.'||r.table_name               into l_tgt;
      if l_src <> l_tgt then
        dbms_output.put_line('ROWCOUNT DIFF '||r.owner||'.'||r.table_name||
                             ' src='||l_src||' tgt='||l_tgt);
      end if;
    exception
      when others then
        dbms_output.put_line('ERROR '||r.owner||'.'||r.table_name||' -> '||sqlerrm);
    end;
  end loop;
end;
/
```

## B2. 主键集合一致性（是否“缺行/多行”）

> 对每张**有主键**的表，比较两边主键集合是否完全一致。下面脚本自动为每表生成 `MINUS` 检查语句并执行统计差异量。

```sql
set serveroutput on size unlimited
declare
  l_link constant varchar2(30) := 'SRC';
  l_sql  clob;
  l_miss_src number; -- 目标有、源没有
  l_miss_tgt number; -- 源有、目标没有
begin
  for t in (
    select uc.owner, uc.table_name,
           listagg(ucc.column_name, ',') within group(order by ucc.position) as pk_cols
    from dba_constraints uc
    join dba_cons_columns ucc
      on ucc.owner=uc.owner and ucc.table_name=uc.table_name and ucc.constraint_name=uc.constraint_name
    where uc.constraint_type='P' and uc.owner in ('APP1','APP2')
    group by uc.owner, uc.table_name
  ) loop
    l_sql := 'select count(*) from ( '||
             'select '||t.pk_cols||' from '||t.owner||'.'||t.table_name||
             ' minus '||
             'select '||t.pk_cols||' from '||t.owner||'.'||t.table_name||'@'||l_link||' )';
    execute immediate l_sql into l_miss_src;

    l_sql := 'select count(*) from ( '||
             'select '||t.pk_cols||' from '||t.owner||'.'||t.table_name||'@'||l_link||
             ' minus '||
             'select '||t.pk_cols||' from '||t.owner||'.'||t.table_name||' )';
    execute immediate l_sql into l_miss_tgt;

    if l_miss_src<>0 or l_miss_tgt<>0 then
      dbms_output.put_line('PK SET DIFF '||t.owner||'.'||t.table_name||
                           ' tgt_not_in_src='||l_miss_src||
                           ' src_not_in_tgt='||l_miss_tgt);
    end if;
  end loop;
end;
/
```

> 如果主键集合一致，但仍不放心“列值是否一致”，进入 C 层比较。

------

# C. 逐行逐列对比（`DBMS_COMPARISON`）

`DBMS_COMPARISON` 是 11g 自带的行级比对工具，能报告“哪几行（按主键/ROWID）有差异、差哪些列”。

### C1. 对单表执行

```sql
begin
  dbms_comparison.create_comparison(
    comparison_name     => 'CMP_APP1_ORDERS',
    schema_name         => 'APP1',
    object_name         => 'ORDERS',
    dblink_name         => 'SRC',
    remote_schema_name  => 'APP1',
    remote_object_name  => 'ORDERS');  -- 有主键最佳；无主键会退化用ROWID
end;
/

declare
  v_scan number; v_equal boolean;
begin
  v_equal := dbms_comparison.compare(
               comparison_name   => 'CMP_APP1_ORDERS',
               scan_id           => v_scan,
               perform_row_dif   => true);
  dbms_output.put_line('Equal? '||case when v_equal then 'YES' else 'NO' end||
                       ' scan_id='||v_scan);
end;
/
-- 汇总与差异明细
select scan_id, difference_rows, local_rows_mismatch, remote_rows_mismatch
from   dba_comparison_scan_summary
where  comparison_name='CMP_APP1_ORDERS'
order  by scan_id desc;

select *
from   dba_comparison_row_dif
where  comparison_name='CMP_APP1_ORDERS'
order  by scan_id desc, index_value;
```

### C2. 批量跑全 schema（示意）

> 把上面的 `create_comparison + compare` 包到一个循环里，遍历 `APP1` 下所有表即可（逻辑同 B2 的循环）。建议先只跑**大表**或**关键业务表**。

------

# D. 其它容易漏掉但要核的点（“一分钟清单”）

- **序列（SEQUENCE）**：导入能带上 `LAST_NUMBER`，但在导出-导入窗口可能发生漂移。

  > 容忍范围通常 ≤ 序列 `CACHE_SIZE`。超出请在目标修正。

  ```sql
  select s.owner, s.sequence_name, s.last_number src_last, t.last_number tgt_last,
         greatest(s.cache_size,t.cache_size) cache_sz
  from dba_sequences@SRC s join dba_sequences t
    on t.owner=s.owner and t.sequence_name=s.sequence_name
  where s.owner in ('APP1','APP2')
    and abs(s.last_number - t.last_number) > greatest(s.cache_size,t.cache_size);
  ```

- **物化视图**：检查是否 `STALE`，必要时做一次 `DBMS_MVIEW.REFRESH`.

  ```sql
  select owner, mview_name, staleness from dba_mviews where owner in ('APP1','APP2');
  ```

- **无效对象**：导入后统一 recompile。

  ```sql
  @?/rdbms/admin/utlrp.sql
  select owner, object_type, count(*) cnt
  from dba_invalid_objects
  where owner in ('APP1','APP2') group by owner, object_type;
  ```

- **作业/链路/目录对象**：连通性与路径是否生效（尤其 DIRECTORY 与 EXTERNAL TABLE）。

------

## 怎么判定“迁移完成”

- **A+B 全绿**（对象数一致、精确行数一致、主键集合一致） ⇒ 基本确认无缺行/多行。
- **C 关键表零差异**（或全库扫描零差异） ⇒ 数据逐列一致。
- 辅助项（序列/MV/无效对象）处理完毕，应用冒烟测试通过 ⇒ 可以宣告完成。

需要的话，我可以把 B1/B2/C 的脚本整理成**可配置 schema 列表**的一键包，或针对你的关键表清单生成“专用对比脚本”。