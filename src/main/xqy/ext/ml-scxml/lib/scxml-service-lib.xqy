xquery version "1.0-ml";

(:
The intent of this library is to provide functions that handle persistence and delegate to scxml-lib for SCXML functionality.
Clients can then interact with scxml-lib when not seeking any persistence operations.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-lib.xqy";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

(:
Start a new instance of the machine with the given ID. Returns the new instance.
:)
declare function start($machine-id as xs:string) as element(mlsc:instance) {
  let $machine := find-machine($machine-id)
  let $instance-id := new-instance-id()
  let $instance := mlsc:start($machine-id, $machine, $instance-id)
  let $uri := build-instance-uri($instance-id)
  return (
    xdmp:document-insert($uri, $instance),
    $instance
  )
};

(:
Trigger the given event on the instance with the given ID. Returns the updated instance.
:)
declare function trigger-event(
  $instance-id as xs:string,
  $event as xs:string
  ) as element(mlsc:instance)
{
  let $instance := get-instance($instance-id)
  let $machine := find-machine(get-machine-id($instance))
  let $new-instance := mlsc:trigger-event($instance, $machine, $event)
  let $_ := xdmp:node-replace($instance, $new-instance)
  return $new-instance
};

(:
Get the instance with the given ID.
:)
declare function get-instance($id as xs:string) as element(mlsc:instance)?
{
  let $uri := build-instance-uri($id)
  where fn:doc-available($uri)
  return fn:doc($uri)/mlsc:instance
};

(:
TODO Will want this to be overrideable, in terms of where the machine is expected to be.
:)
declare function find-machine($machine-id as xs:string) as element(sc:scxml)
{
  xdmp:eval("
    xquery version '1.0-ml';
    declare variable $machine-id as xs:string external;
    let $uri := fn:concat('/ext/ml-scxml/machines/' || $machine-id || '.xml')
    return fn:doc($uri)",
    (xs:QName("machine-id"), $machine-id),
    <options xmlns="xdmp:eval">
      <database>{xdmp:modules-database()}</database>
    </options>
  )/sc:scxml
};

declare function build-instance-uri($instance-id as xs:string) as xs:string
{
  "/ml-scxml/instances/" || $instance-id || ".xml"
};

declare function new-instance-id() as xs:string
{
  (: TODO Is this callable without the semantics license? :)
  sem:uuid-string()
};
