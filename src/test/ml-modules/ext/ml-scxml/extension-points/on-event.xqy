xquery version "1.0-ml";

(:
Extension point for custom logic for when an event is raised.
:)

module namespace mlscxp = "http://marklogic.com/scxml/extension-points";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-service-lib.xqy", "/ext/ml-scxml/lib/scxml-lib.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare function on-event(
  $event-id as xs:string,
  $state as element()?,
  $machine as element(sc:scxml),
  $instance as element(mlsc:instance)
  ) as empty-sequence()
{
  xdmp:document-insert(
    "/ml-scxml/event/" || mlsc:get-instance-id($instance) || "/" || $event-id || ".xml", 
    <mlsc:test-event>{$event-id}</mlsc:test-event>,
    (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update"))
  )
};
