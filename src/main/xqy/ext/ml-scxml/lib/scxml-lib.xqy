xquery version "1.0-ml";

module namespace mlsc = "http://marklogic.com/scxml";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare function start($name as xs:string) {
  let $sc := find-statechart($name)
  let $initial-state := ($sc/(sc:state|sc:final)[@id = $sc/@initial], $sc/sc:state[1])[1]
  let $instance := element mlsc:instance {
    attribute createdDateTime {fn:current-dateTime()},
    element mlsc:state {fn:string($initial-state/@id)},
    $sc/sc:datamodel
  }
  let $instance := enter-state($initial-state, $sc, $instance)
  return $instance  
};

(:
TODO Will want this to be overrideable, in terms of where the statechart is expected to be.
:)
declare function find-statechart($name as xs:string) as element(sc:scxml)
{
  xdmp:eval("
    xquery version '1.0-ml';
    declare variable $NAME as xs:string external;
    let $uri := fn:concat('/ext/ml-scxml/statecharts/' || $NAME || '.xml')
    return fn:doc($uri)",
    (xs:QName("NAME"), $name),
    <options xmlns="xdmp:eval">
      <database>{xdmp:modules-database()}</database>
    </options>
  )/sc:scxml
};

declare function enter-state($state, $sc, $instance)
{
  let $datamodel := $instance/sc:datamodel
  let $_ := 
    for $el in $state/sc:onentry/element()
    return typeswitch ($el)
      case element(sc:log) return xdmp:log(xdmp:eval($el/@expr))
      case element(sc:assign) return

        let $location := $el/@location/fn:string()
        let $var := fn:substring(fn:tokenize($location, "/")[1], 2)
        let $path := "/" || fn:substring-after($location, "/")
        let $expr := $el/@expr/fn:string()
        
        let $stylesheet := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:sc="http://www.w3.org/2005/07/scxml">
        <xsl:template match="*">
            <xsl:copy>
              <xsl:copy-of select="attribute::*" />
              <xsl:apply-templates />
            </xsl:copy>
          </xsl:template>
        <xsl:template match="sc:data[@id = '{$var}']{$path}">
          <xsl:copy>
            <xsl:value-of select="{$expr}"/>
          </xsl:copy>
        </xsl:template>
        </xsl:stylesheet>
        return xdmp:set($datamodel, xdmp:xslt-eval($stylesheet, $datamodel))
        
      default return ()

  return element {fn:node-name($instance)} {
    $instance/@*,
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:state) return element mlsc:state {$state/@id/fn:string()}
      case element(sc:datamodel) return $datamodel
      default return $kid
  }
};
