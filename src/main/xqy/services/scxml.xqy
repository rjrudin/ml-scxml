xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/scxml";

import module namespace mlsc = "http://marklogic.com/scxml" at "/ext/ml-scxml/lib/scxml-lib.xqy";

declare function get(
  $context as map:map,
  $params  as map:map
  ) as document-node()*
{
  xdmp:log("GET called")
};

declare function post(
  $context as map:map,
  $params  as map:map,
  $input   as document-node()*
  ) as document-node()*
{
  let $sc-name := map:get($params, "statechartId")
  let $instance-id := mlsc:start($sc-name)
  return document {
    xdmp:to-json(
      let $o := json:object()
      return (
        map:put($o, "instanceId", $instance-id),
        $o
      )
    )
  }
};
