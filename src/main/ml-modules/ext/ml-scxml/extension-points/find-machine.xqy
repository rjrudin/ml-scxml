xquery version "1.0-ml";

(:
Extension point for finding a statechart machine based on a unique identifier. 
:)

module namespace mlscxp = "http://marklogic.com/scxml/extension-points";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

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

