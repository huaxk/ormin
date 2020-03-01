import unittest, json, postgres, strformat, strutils, sequtils, macros, times
from db_postgres import exec, getValue
import ormin

importModel(DbBackend.postgre, "model_postgre")

type
  AllType = tuple[typinteger: int,
                  typbool: bool,
                  typfloat: float,
                  typjson: JsonNode,
                  jsonstr: string,
                  typtimestamp: DateTime
                ]

var typedata: seq[AllType]

let rowcount = 5
for i in 1..rowcount:
  typedata.add((typinteger: i,
                typbool: i mod 2 == 0,
                typfloat: 0.5 + i.float,
                typjson: %*{"name": &"bob{i}", "age": 29 + i},
                jsonstr: $(%*{"type": "Point", "coordinates": [i, i.float]}),
                typtimestamp: initDateTime(30, mMar, 2019, i, i, i),
              ))

suite "postgre_special":
  let db {.global.} = open("localhost", "test", "test", "test")

  setup:
    db.exec(sql"delete from alltype")

    for t in typedata:
      query:
        insert alltype(typinteger = ?t.typinteger,
                       typbool = ?t.typbool,
                       typfloat = ?t.typfloat,
                       typjson = ?(t.typjson),
                       jsonstr = ?(t.jsonstr),
                       typtimestamp = ?(t.typtimestamp))
    check db.getValue(sql"select count(*) from alltype") == $rowcount

  test "query_dbSerial":
    let res = query:
      select alltype(typserial)
    for s in res:
      check s != 0
    let resjson = query:
      select alltype(typserial)
      produce json
    for j in resjson:
      check j.kind == JObject
      check j["typserial"].getInt() != 0

  test "query_dbVarchar":
    let res = query:
      select alltype(jsonstr)
    check res == typedata.mapIt(it.jsonstr)
    let resjson = query:
      select alltype(jsonstr)
      produce json
    check resjson == %typedata.mapIt(%*{"jsonstr": it.jsonstr})

  test "query_dbInteger":
    let res = query:
      select alltype(typinteger)
    check res == typedata.mapIt(it.typinteger)
    let resjson = query:
      select alltype(typinteger)
      produce json
    check resjson == %typedata.mapIt(%*{"typinteger": it.typinteger})

  test "query_dbBool":
    let res = query:
      select alltype(typbool)
    check res == typedata.mapIt(it.typbool)
    let resjson = query:
      select alltype(typbool)
      produce json
    check resjson == %typedata.mapIt(%*{"typbool": it.typbool})

  test "query_dbFloat":
    let res = query:
      select alltype(typfloat)
    check res == typedata.mapIt(it.typfloat)
    let resjson =query:
      select alltype(typfloat)
      produce json
    check resjson == %typedata.mapIt(%*{"typfloat": it.typfloat})

  test "query_dbJson":
    let res = query:
      select alltype(typjson)
    check res == typedata.mapIt(it.typjson)
    let resjson = query:
      select alltype(typjson)
      produce json
    check resjson == %typedata.mapIt(%*{"typjson": it.typjson})

  test "query datetime":
    let res = query:
      select alltype(typtimestamp)
    check res.mapIt($it) == typedata.mapIt($it.typtimestamp)
    let resjson = query:
      select alltype(typtimestamp)
      produce json
    check resjson == %typedata.mapIt(%*{"typtimestamp": it.typtimestamp.format(jsonDateTimeFormat)})

  db.close()
