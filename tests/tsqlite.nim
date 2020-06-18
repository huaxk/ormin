import unittest, sqlite3, json, times
from db_sqlite import exec, getValue
import ormin
import ./utils

importModel(DbBackend.sqlite, "model_sqlite")

let
  db {.global.} = open("test.db", "", "", "")
  testDir = currentSourcePath.parentDir()
  sqlFile = testDir / "model_sqlite.sql"


suite "Test special database types and functions of sqlite":
  discard

jsonTimeFormat = "yyyy-MM-dd HH:mm:ss\'.\'fff"
let
  dtStr1 = "2018-02-20 02:02:02"
  dt1 = parse(dtStr1, "yyyy-MM-dd HH:mm:ss", utc())
  dtStr2 = "2019-03-30 03:03:03.123"
  dt2 = parse(dtStr2, "yyyy-MM-dd HH:mm:ss\'.\'fff", utc())
  dtjson = %*{"dt1": dt1.format(jsonTimeFormat),
              "dt2": dt2.format(jsonTimeFormat)}
let insertSql =  sql"insert into tb_timestamp(dt1, dt2) values (?, ?)"

suite "timestamp_insert":
  setup:
    db.dropTable(sqlFile, "tb_timestamp")
    db.createTable(sqlFile, "tb_timestamp")

  test "insert":
    query:
      insert tb_timestamp(dt1 = ?dt1, dt2 = ?dt2)
    check db.getValue(sql"select count(*) from tb_timestamp") == "1"

  test "json":
    query:
      insert tb_timestamp(dt1 = %dtjson["dt1"], dt2 = %dtjson["dt2"])
    check db.getValue(sql"select count(*) from tb_timestamp") == "1"

suite "timestamp":
  db.dropTable(sqlFile, "tb_timestamp")
  db.createTable(sqlFile, "tb_timestamp")

  db.exec(insertSql, dtStr1, dtStr2)
  doAssert db.getValue(sql"select count(*) from tb_timestamp") == "1"

  test "query":
    let res = query:
      select tb_timestamp(dt1, dt2)
    check res == [(dt1, dt2)]

  test "where":
    let res = query:
      select tb_timestamp(dt1, dt2)
      where dt1 == ?dt1
    check res == [(dt1, dt2)]

  test "in":
    let
      duration = initDuration(hours = 1)
      dtStart = dt1 - duration
      dtEnd = dt1 + duration
      res2 = query:
        select tb_timestamp(dt1, dt2)
        where dt1 in ?dtStart .. ?dtEnd
    check res2 == [(dt1, dt2)]

  test "iter":
    createIter iter:
      select tb_timestamp(dt1, dt2)
      where dt1 == ?dt1
    var res: seq[tuple[dt1: DateTime, dt2: DateTime]]
    for it in db.iter(dt1):
      res.add(it)
    check res == [(dt1, dt2)]

  test "proc":
    createProc aproc:
      select tb_timestamp(dt1, dt2)
      where dt1 == ?dt1
    check db.aproc(dt1) == [(dt1, dt2)]

  test "json":
    let res = query:
      select tb_timestamp(dt1, dt2)
      produce json
    check res == %*[dtjson]
  
  test "json_where":
    let res = query:
      select tb_timestamp(dt1, dt2)
      where dt1 == %dtjson["dt1"]
      produce json
    check res == %*[dtjson]


type
  Student = object
    name: string
    age: int

let
  name = "bob"
  age = 20
  student = Student(name: name, age: age)
  bytes = [21'u8, 25'u8, 26'u8, 27'u8]
  ints = [21, 25, 26, 27]
  students = [
    Student(name: "bob", age: 20),
    Student(name: "jack", age: 30),
    Student(name: "tom", age: 34)
  ]

proc toSeq*[T](b: Blob): seq[T] =
  let (val, len) = b
  result = newSeq[T](len div sizeof(T))
  copyMem(result[0].addr, val, len)

proc toObject*[T](b: Blob): T =
  let (val, _) = b
  result = cast[ptr T](val)[]

suite "blob":
  setup:
    db.dropTable(sqlFile, "tb_blob")
    db.createTable(sqlFile, "tb_blob")
  
  test "bytes":
    let b = (bytes, bytes.sizeof)
    query:
      insert tb_blob(typblob = ?b)
    let res = query:
      select tb_blob(typblob)
      limit 1
    let r = toSeq[byte](res)
    check r == bytes

  test "ints":
    let b = (ints, ints.sizeof)
    query:
      insert tb_blob(typblob = ?b)
    let res = query:
      select tb_blob(typblob)
      limit 1
    let r = toSeq[int](res)
    check r == ints

  test "object":
    let b = (student, student.sizeof)
    query:
       insert tb_blob(typblob = ?b)
    let res = query:
      select tb_blob(typblob)
      limit 1
    let r = toObject[Student](res)
    check r == student

  test "objects":
    let b = (students, students.sizeof)
    query:
      insert tb_blob(typblob = ?b)
    let res = query:
      select tb_blob(typblob)
      limit 1
    let r = toSeq[Student](res)
    check r == students
