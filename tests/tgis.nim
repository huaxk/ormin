import unittest, os, json
import ormin
import ./utils
from db_postgres import exec, getValue

const
  sqlFileName = "model_gis.sql"
  testDir = currentSourcePath.parentDir()
  sqlFile = testDir / sqlFileName

importModel(DbBackend.postgre, "model_gis")

let db {.global.} = open("localhost", "test", "test", "test")

static:
  functions.add([
    Function(name: "st_geomfromtext", arity: 2, typ: dbVarchar),
    Function(name: "st_astext", arity: 1, typ: dbVarchar),
    Function(name: "st_asgeojson", arity: 1, typ: dbJson)
  ])

suite "postgis":
  let exist = db.getValue(sql"select count(*) from pg_class where relname='spatial_ref_sys'")
  if exist == "0":
    db.exec(sql"create extension postgis")

  db.dropTable(sqlFile, "place")
  db.createTable(sqlFile, "place")

  let wkts = [
    "point(116 40)",
    "point(100.32 32.5)",
    "point(165.0 88.8)"
  ]
  for pt in wkts:
    query:
      insert place(name = "huaian", lnglat = st_geomfromtext(?pt, 4326))

  let res = query:
    select place(id, name, st_astext(lnglat) as lnglat)
  echo res
