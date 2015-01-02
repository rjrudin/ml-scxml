xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/scxml";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-service-lib.xqy", "/ext/ml-scxml/lib/scxml-lib.xqy";

declare function get(
  $context as map:map,
  $params  as map:map
  ) as document-node()*
{
  document {
    mlsc:get-instance(map:get($params, "instanceId")),
    xdmp:set-response-content-type("application/xml")
  }
};

declare function post(
  $context as map:map,
  $params  as map:map,
  $input   as document-node()*
  ) as document-node()*
{
  let $sc-name := map:get($params, "statechartId")
  return
    if ($sc-name) then 
      document {
        xdmp:to-json(
          let $o := json:object()
          return (
            map:put($o, "instanceId", mlsc:start($sc-name)),
            $o,
            xdmp:set-response-content-type("application/json")
          )
        )
      }
    else
      let $instance := mlsc:trigger-event(map:get($params, "instanceId"), map:get($params, "event"))
      return document {
        xdmp:to-json(
          let $o := json:object()
          return (
            map:put($o, "instanceId", mlsc:get-instance-id($instance)),
            map:put($o, "state", mlsc:get-state($instance)),
            $o
          )
        )
      }
};
