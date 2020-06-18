import unittest, postgres, json, strutils, macros, times, os
import ormin
from db_postgres import exec, getValue
import ./utils

importModel(DbBackend.postgre, "model_postgre")

let
  db {.global.} = open("localhost", "test", "test", "test")
  testDir = currentSourcePath.parentDir()
  sqlFile = testDir / "model_postgre.sql"


suite "Test special database types and functions of postgre":
  discard

let
  dtStr1 = "2018-03-30 01:01:01"
  dt1 = parse(dtStr1, "yyyy-MM-dd HH:mm:ss")
  dtnStr1 = "2019-03-30 11:02:02+08"
  dtn1 = parse(dtnStr1, "yyyy-MM-dd HH:mm:sszz")
  dtzStr1 = "2020-03-30 09:03:03Z"
  dtz1 = parse(dtzStr1, "yyyy-MM-dd HH:mm:sszz")
  dtStr2 = "2018-03-30 01:01:01.123"
  dt2 = parse(dtStr2, "yyyy-MM-dd HH:mm:ss\'.\'fff")
  dtnStr2 = "2019-03-30 11:02:02.123+08"
  dtn2 = parse(dtnStr2, "yyyy-MM-dd HH:mm:ss\'.\'fffzz")
  dtzStr2 = "2020-03-30 09:03:03.123Z"
  dtz2 = parse(dtzStr2, "yyyy-MM-dd HH:mm:ss\'.\'fffzz")
  dtStr3 = "2018-03-30 01:01:01.123456"
  dt3 = parse(dtStr3, "yyyy-MM-dd HH:mm:ss\'.\'ffffff")
  dtnStr3 = "2019-03-30 11:02:02.123456+08"
  dtn3 = parse(dtnStr3, "yyyy-MM-dd HH:mm:ss\'.\'ffffffzz")
  dtzStr3 = "2020-03-30 09:03:03.123456Z"
  dtz3 = parse(dtzStr3, "yyyy-MM-dd HH:mm:ss\'.\'ffffffzz")
  dtjson1 = %*{"dt": dt1.format(jsonTimeFormat),
              "dtn": dtn1.format(jsonTimeFormat),
              "dtz": dtz1.format(jsonTimeFormat)}
  dtjson2 = %*{"dt": dt2.format(jsonTimeFormat),
              "dtn": dtn2.format(jsonTimeFormat),
              "dtz": dtz2.format(jsonTimeFormat)}
  dtjson3 = %*{"dt": dt3.format(jsonTimeFormat),
              "dtn": dtn3.format(jsonTimeFormat),
              "dtz": dtz3.format(jsonTimeFormat)}

let insertSql =  sql"insert into tb_timestamp(dt, dtn, dtz) values (?, ?, ?)"
            
suite "timestamp_insert":
  setup:
    db.dropTable(sqlFile, "tb_timestamp")
    db.createTable(sqlFile, "tb_timestamp")

  test "insert":
    query:
      insert tb_timestamp(dt = ?dt1, dtn = ?dtn1, dtz = ?dtz1)
    check db.getValue(sql"select count(*) from tb_timestamp") == "1"

  test "json":
    query:
      insert tb_timestamp(dt = %dtjson1["dt"],
                          dtn = %dtjson1["dtn"],
                          dtz = %dtjson1["dtz"])
    check db.getValue(sql"select count(*) from tb_timestamp") == "1"

suite "timestamp":
  db.dropTable(sqlFile, "tb_timestamp")
  db.createTable(sqlFile, "tb_timestamp")

  db.exec(insertSql, dtStr1, dtnStr1, dtzStr1)
  db.exec(insertSql, dtStr2, dtnStr2, dtzStr2)
  db.exec(insertSql, dtStr3, dtnStr3, dtzStr3)
  doAssert db.getValue(sql"select count(*) from tb_timestamp") == "3"

  test "query":
    let res = query:
      select tb_timestamp(dt, dtn, dtz)
    check res == [(dt1, dtn1, dtz1),
                  (dt2, dtn2, dtz2),
                  (dt3, dtn3, dtz3)]

  test "where":
    let res = query:
      select tb_timestamp(dt)
      where dt == ?dt1
    check res == [dt1]

  test "in":
    let
      duration = initDuration(hours = 1)
      dtStart = dt1 - duration
      dtEnd = dt1 + duration
      res2 = query:
        select tb_timestamp(dt)
        where dt in ?dtStart .. ?dtEnd
    check res2 == [dt1, dt2, dt3]

  test "iter":
    createIter iter:
      select tb_timestamp(dt)
      where dt == ?dt
    var res: seq[DateTime]
    for it in db.iter(dt1):
      res.add(it)
    check res == [dt1]

  test "proc":
    createProc aproc:
      select tb_timestamp(dt)
      where dt == ?dt
    check db.aproc(dt1) == [dt1]

  test "json":
    let res = query:
      select tb_timestamp(dt, dtn, dtz)
      produce json
    check res == %*[dtjson1, dtjson2, dtjson3]
  
  test "json_where":
    let res = query:
      select tb_timestamp(dt, dtn, dtz)
      where dt == %dtjson1["dt"]
      produce json
    check res[0] == dtjson1


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
  let
    (val, len) = b
    hexStr = ($val)[2..<len]
    hexLen = len-2
    seqLen = hexLen div (2 * sizeof(T))
    binStr = parseHexStr(hexStr)
  echo val
  echo len
  echo toHex(binStr)
  result = newSeq[T](seqLen)
  copyMem(result[0].addr, binStr.cstring, hexLen)

proc toObject*[T](b: Blob): T =
  let
    (val, len) = b
    hexStr = ($val)[2..<len]
    hexLen = len - 2
    binStr = parseHexStr(hexStr)
    binLen = hexLen div 2
  echo hexStr.len, hexLen
  echo binStr.len, binLen
  # result = cast[ptr T](binStr.cstring)[]
  copyMem(result.addr, (binStr.cstring).unsafeAddr, binLen)

suite "blob":
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
    echo toSeq[int](res)

  test "object":
    let b = (student, student.sizeof)
    query:
       insert tb_blob(typblob = ?b)
    let res = query:
      select tb_blob(typblob)
      limit 1
    echo b
    echo res
    let r = toObject[Student](res)
    echo r.name
    # check r == student 
