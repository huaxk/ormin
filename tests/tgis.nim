import unittest, os, json, sequtils, strformat, strutils
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
    Function(name: "st_geomfromtext", arity: -1, typ: dbVarchar),
    Function(name: "st_geomfromewkt", arity: 1, typ: dbVarchar),
    Function(name: "st_geomfromgeojson", arity: 1, typ: dbVarchar),
    Function(name: "st_pointfromtext", arity: -1, typ: dbVarchar),
    Function(name: "st_makepoint", arity: -1, typ: dbVarchar),
    Function(name: "st_makepointm", arity: 3, typ: dbVarchar),
    Function(name: "st_point", arity: 2, typ: dbVarchar),
    Function(name: "st_setsrid", arity: 2, typ: dbVarchar),
    Function(name: "st_srid", arity: 1, typ: dbInt),
    Function(name: "geometrytype", arity: 1, typ: dbVarchar),
    Function(name: "st_x", arity: 1, typ: dbFloat),
    Function(name: "st_y", arity: 1, typ: dbFloat),
    Function(name: "st_astext", arity: 1, typ: dbVarchar),
    Function(name: "st_asewkt", arity: 1, typ: dbVarchar),
    Function(name: "st_asgeojson", arity: 1, typ: dbJson),
  ])

let exist = db.getValue(sql"select count(*) from pg_class where relname='spatial_ref_sys'")
if exist == "0":
  db.exec(sql"create extension postgis")

suite "postgis_insert":
  setup:
    db.dropTable(sqlFile, "place")
    db.createTable(sqlFile, "place")

  test "geomfromtext":
    let wkt = "POINT(-77.0092 38.889588)"
    query:
      insert place(name = "name geomfromtext", lnglat = st_geomfromtext(?wkt))
    check db.getValue(sql"select count(*) from place") == "1"

  test "geomfromtext2":
    let ewkt = "POINT(-77.0092 38.889588)"
    query:
      insert place(name = "name geomfromtext", lnglat = st_geomfromtext(?ewkt, 4326))
    check db.getValue(sql"select count(*) from place") == "1"

  test "geomfromewkt":
    let ewkt = "SRID=4326;POINT(-77.0092 38.889588)"
    query:
      insert place(name = "name geomfromtext", lnglat = st_geomfromewkt(?ewkt))
    check db.getValue(sql"select count(*) from place") == "1"

  test "pointfromtext":
    let wkt = "POINT(-77.0092 38.889588)"
    query:
      insert place(name = "name pointfromtext", lnglat = st_pointfromtext(?wkt))
    check db.getValue(sql"select count(*) from place") == "1"

  test "pointfromtext2":
    let ewkt = "POINT(-77.0092 38.889588)"
    query:
      insert place(name = "name pointfromtext", lnglat = st_pointfromtext(?ewkt, 4326))
    check db.getValue(sql"select count(*) from place") == "1"

  test "geomfromgeojson":
    let geojson = """{"type":"Point","coordinates":[-48.23456,20.12345]}"""
    query:
      insert place(name = "name geojson", lnglat = st_geomfromgeojson(?geojson))
    check db.getValue(sql"select count(*) from place") == "1"

  test "makepoint":
    query:
      insert place(name = "name makepoint", lnglat = st_makepoint(-71.1043443253471, 42.3150676015829, 35))
    check db.getValue(sql"select count(*) from place") == "1"

  test "makepointm":
    query:
      insert place(name = "name makepointm", lnglat = st_makepointm(-71.1043443253471, 42.3150676015829, 35))
    check db.getValue(sql"select count(*) from place") == "1"

  test "point":
    query:
      insert place(name = "name point", lnglat = st_point(-71.104, 42))
    check db.getValue(sql"select count(*) from place") == "1"

  test "setsrid":
    query:
      insert place(name = "name setsrid", lnglat = st_setsrid(st_point(-71.104, 42), 4326))
    check db.getValue(sql"select count(*) from place") == "1"


suite "postgis_query":
  db.dropTable(sqlFile, "place")
  db.createTable(sqlFile, "place")

  let
    srid = 4326
    places = [
      (id: 1, name: "name1", lnglat: "POINT(116 40)", coordinates: %*[116, 40]),
      (id: 2, name: "name2", lnglat: "POINT(100.32 32.5)", coordinates: %*[100.32, 32.5]),
      (id: 3, name: "name3", lnglat: "POINT(165 88.8)", coordinates: %*[165, 88.8])
    ]

  for p in places:
    query:
      insert place(name = ?p[1], lnglat = st_geomfromtext(?p[2], ?srid))
  doAssert db.getValue(sql"select count(*) from place") == $places.len

  test "srid":
    let res = query:
      select place(st_srid(lnglat) as srid)
      limit 1
    check res == srid

  test "geometrytype":
    let res = query:
      select place(geometrytype(lnglat))
      limit 1
    check res == "POINT"

  test "x":
    let res = query:
      select place(st_x(lnglat))
    check res == places.mapIt(it.lnglat
                                .split({'(', ')', ' '})[1]
                                .parseFloat()
                              )

  test "y":
    let res = query:
      select place(st_y(lnglat))
    check res == places.mapIt(it.lnglat
                                .split({'(', ')', ' '})[2]
                                .parseFloat()
                              )

  test "astext":
    let res = query:
      select place(st_astext(lnglat) as lnglat)
    check res == places.mapIt(it.lnglat)

  test "asewkt":
    let res = query:
      select place(st_asewkt(lnglat) as lnglat)
    check res == places.mapIt(&"SRID={srid};{it.lnglat}")

  test "asgeojson":
    let res = query:
      select place(st_asgeojson(lnglat) as lnglat)
    check res == places.mapIt(%*{"type": "Point", "coordinates": it.coordinates})
