import unittest, os, json, sequtils
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
    Function(name: "st_asgeojson", arity: 1, typ: dbJson),
    Function(name: "st_setsrid", arity: 2, typ: dbVarchar),
    Function(name: "st_point", arity: 2, typ: dbVarchar),
  ])

suite "postgis":
  let exist = db.getValue(sql"select count(*) from pg_class where relname='spatial_ref_sys'")
  if exist == "0":
    db.exec(sql"create extension postgis")

  db.dropTable(sqlFile, "place")
  db.createTable(sqlFile, "place")

  let places = [
    (id: 1, name: "name1", lnglat: "POINT(116 40)", coordinates: %*[116, 40]),
    (id: 2, name: "name2", lnglat: "POINT(100.32 32.5)", coordinates: %*[100.32, 32.5]),
    (id: 3, name: "name3", lnglat: "POINT(165 88.8)", coordinates: %*[165, 88.8])
  ]

  for p in places:
    query:
      insert place(name = ?p[1], lnglat = st_geomfromtext(?p[2], 4326))
  doAssert db.getValue(sql"select count(*) from place") == $places.len

  test "st_astext":
    let res = query:
      select place(st_astext(lnglat) as lnglat)
    check res == places.mapIt(it.lnglat)

  test "st_asgeojson":
    let res = query:
      select place(st_asgeojson(lnglat) as lnglat)
    check res == places.mapIt(%*{"type": "Point", "coordinates": it.coordinates})

  test "st_point":
    query:
      insert place(name = "name5", lnglat = st_setsrid(st_point(-71.104, 42), 4326))
