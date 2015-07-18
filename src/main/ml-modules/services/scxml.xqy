xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/scxml";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-service-lib.xqy", "/ext/ml-scxml/lib/scxml-lib.xqy";

declare namespace rapi = "http://marklogic.com/rest-api";

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

declare %rapi:transaction-mode("update") function post(
  $context as map:map,
  $params  as map:map,
  $input   as document-node()*
  ) as document-node()*
{
  let $instance-id := map:get($params, "instanceId")
  return
    if ($instance-id) then 
      instance-to-json(
        mlsc:handle-event($instance-id, map:get($params, "event"))
      )
    else
      instance-to-json(
        mlsc:start(map:get($params, "machineId"))
        
      )
};

declare private function instance-to-json($instance as element(mlsc:instance)) as document-node()
{
  document {
    xdmp:to-json(
      let $o := json:object()
      return (
        map:put($o, "instanceId", mlsc:get-instance-id($instance)),
        map:put($o, "state", mlsc:get-state($instance)),
        $o,
        xdmp:set-response-content-type("application/json")
      )
    )
  }
};
