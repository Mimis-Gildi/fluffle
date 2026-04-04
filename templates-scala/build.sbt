// https://www.scala-sbt.org/1.x/docs/index.html

ThisBuild / organization := "me.lugaru.virt"
ThisBuild / name := "templates-scala"
ThisBuild / version := "0.1.0-SNAPSHOT"

ThisBuild / scalaVersion := "3.6.4"

lazy val root = (project in file("."))
  .settings(
    name := "templates-scala",
    idePackagePrefix := Some("me.lugaru.virt")
  )
