xquery version "1.0-ml";

(:
The intent of this library is to provide functions that handle persistence and delegate to scxml-lib for SCXML functionality.
Clients can then interact with scxml-lib when not seeking any persistence operations.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-lib.xqy";
import module namespace mlscxp = "http://marklogic.com/scxml/extension-points" at "/ext/ml-scxml/extension-points/find-machine.xqy";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";


(:
Start a new instance of the machine with the given ID. Returns the new instance.
:)
declare function start($machine-id as xs:string) as element(mlsc:instance) {
  let $machine := mlscxp:find-machine($machine-id)
  let $instance-id := new-instance-id()
  let $instance := mlsc:start($machine-id, $machine, $instance-id)
  let $uri := build-instance-uri($instance-id)
  return (
    xdmp:document-insert($uri, $instance, (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update"))),
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
  let $machine := mlscxp:find-machine(get-machine-id($instance))
  let $new-instance := mlsc:trigger-event($instance, $machine, $event)
  let $_ := xdmp:node-replace($instance, $new-instance)
  return $new-instance
};


(:
Get the instance with the given ID. In the future, may have an overloaded function that allows for the instance to be
missing, but for now, we always expect to get something back.
:)
declare function get-instance($id as xs:string) as element(mlsc:instance)
{
  let $uri := build-instance-uri($id)
  return
    if (fn:doc-available($uri)) then 
      fn:doc($uri)/mlsc:instance
    else
      fn:error(xs:QName("MISSING-INSTANCE"), "Could not find an instance with ID: " || $id)
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
