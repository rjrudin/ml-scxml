What is ml-scxml?
========

ml-scxml is an implementation of the [SCXML](http://www.w3.org/TR/scxml/) spec written in XQuery on MarkLogic. 

What ml-scxml provides:

1. A set of libraries that can be included in your application that conform to the lastest SCXML spec.
2. A REST API endpoint for starting new workflow instances and firing events.

What ml-scxml doesn't provide:

1. A GUI for authoring and managing state machine definitions.
2. A GUI for managing state machine instances.

How do I use ml-scxml?
========
More to come on this soon, but here are the basics:

1. Load your SCXML documents (your state machine definitions) into /ext/ml-scxml/machines
2. To create a new instance of a state machine, make a POST to /v1/resources/scxml?rs:machineId=(name of your machine), where "name of your machine" matches your machine module filename minus the ".xml"
3. To fire an event into an existing instance, make a POST to /v1/resource/scxml?rs:instanceId=(the instance ID)&rs:event=(the event name).

For examples, see https://github.com/rjrudin/ml-scxml/tree/master/src/test/ml-modules/ext/ml-scxml/machines. The only other docs are right now are all the [JUnit test cases](https://github.com/rjrudin/ml-scxml/tree/master/src/test/java/com/marklogic/scxml).
