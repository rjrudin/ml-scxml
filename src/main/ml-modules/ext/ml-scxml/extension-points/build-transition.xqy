xquery version "1.0-ml";

(:
Extension point for building a transition that is then persisted on the instance document as a record of that 
transition occurring. I don't anticipate that ml-scxml will have dependencies on the data that is recorded here - this
is really for auditing/analytics.
:)

module namespace mlscxp = "http://marklogic.com/scxml/extension-points";

declare namespace mlsc = "http://marklogic.com/scxml";
declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare function build-transition(
  $new-states as element()+,
  $current-state as element()?,
  $machine as element(sc:scxml), 
  $instance as element(mlsc:instance)
  ) as element(mlsc:transition)
{
  (: Using attributes for states here, as I don't think we'd want them to hit on free text searches :)
  (: TODO Unique QName based on "to" state, or stick with generic QName? :)
  for $new-state in $new-states
  return 
    <mlsc:transition date-time="{fn:current-dateTime()}">
      {
      if ($current-state) then 
        <mlsc:from state="{fn:string($current-state/@id)}"/>
      else (),
      
      for $new-state in $new-states
      return <mlsc:to state="{fn:string($new-state/@id)}"/> 
      }
    </mlsc:transition>
};
