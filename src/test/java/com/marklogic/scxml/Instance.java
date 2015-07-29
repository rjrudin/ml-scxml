package com.marklogic.scxml;

import com.marklogic.junit.Fragment;

public class Instance extends Fragment {

    public Instance(Fragment other) {
        super(other);
    }

    public void assertMachineId(String machineId) {
        assertElementValue("/mlsc:instance/mlsc:machine-id", machineId);
    }

    public void assertInstanceId(String instanceId) {
        assertElementValue("/mlsc:instance/mlsc:instance-id", instanceId);
    }

    public void assertCurrentState(String state) {
        assertElementValue("/mlsc:instance/mlsc:current-states/mlsc:current-state", state);
    }

    public void assertCurrentStates(String... states) {
        for (String state : states) {
            assertCurrentState(state);
        }
        String xpath = "/mlsc:instance/mlsc:current-states/mlsc:current-state[%d]";
        assertElementExists(format(xpath, states.length));
        assertElementMissing("Expected " + xpath + " to not exist", format(xpath, states.length + 1));
    }

    public void assertDatamodelElementExists(String dataId, String xpath) {
        String path = format("/mlsc:instance/sc:datamodel/sc:data[@id = '%s']/%s", dataId, xpath);
        assertElementExists(path);
    }

    /**
     * This is for transitions that occur when a state machine starts up, where there is no exit state.
     * 
     * @param position
     * @param enterState
     */
    public void assertTransitionExists(int position, String enterState) {
        assertTransitionExists(position, null, null, enterState);
    }

    public void assertTransitionExists(int position, String event, String exitState, String enterState) {
        if (exitState == null && event == null) {
            assertElementExists(format(
                    "/mlsc:instance/mlsc:transitions/mlsc:transition[%d][not(mlsc:exit) and not(@event) and mlsc:enter/@state = '%s' and @transition-dateTime != '']",
                    position, enterState));
        } else if (event == null) {
            assertElementExists(format(
                    "/mlsc:instance/mlsc:transitions/mlsc:transition[%d][not(@event) and @transition-dateTime != '' and mlsc:exit/@state = '%s' and mlsc:enter/@state = '%s']",
                    position, exitState, enterState));
        } else {
            assertElementExists(format(
                    "/mlsc:instance/mlsc:transitions/mlsc:transition[%d][@event = '%s' and @transition-dateTime != '' and mlsc:exit/@state = '%s' and mlsc:enter/@state = '%s']",
                    position, event, exitState, enterState));
        }
    }

    public void assertTransitionCount(String message, int count) {
        String xpath = "/mlsc:instance/mlsc:transitions/mlsc:transition[%d]";
        assertElementExists(message, format(xpath, count));
        assertElementMissing(message, format(xpath, count + 1));
    }

    public void assertTestMessageExists(int position, String message) {
        assertElementExists(format("/mlsc:instance/message[%d][. = '%s']", position, message));
    }
}
