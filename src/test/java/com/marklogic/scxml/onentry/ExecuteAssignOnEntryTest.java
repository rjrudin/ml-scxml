package com.marklogic.scxml.onentry;

import org.junit.Before;
import org.junit.Test;

import com.jayway.restassured.path.json.JsonPath;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteAssignOnEntryTest extends AbstractScxmlTest {

    private String instanceId;

    @Before
    public void setup() {
        instanceId = startMachineWithId("assign");

        Instance i = loadInstance(instanceId);
        i.assertMachineId("assign");
        i.assertInstanceId(instanceId);
        i.assertState("first");
        i.assertDatamodelElementExists("ticket", "price[. = '0']");
    }

    @Test
    public void executeS1AssignmentOnEntry() {
        Response r = triggerEvent(instanceId, "e");
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        assertEquals("s1", json.getString("state"));

        Instance i = loadInstance(instanceId);
        i.assertState("s1");
        i.assertDatamodelElementExists("ticket", "price[. = '10']");
    }

    @Test
    public void executeS2AssignmentOnEntry() {
        Response r = triggerEvent(instanceId, "e2");
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        assertEquals("s2", json.getString("state"));

        Instance i = loadInstance(instanceId);
        i.assertState("s2");
        i.assertDatamodelElementExists("ticket", "price[. = '20']");
    }

    @Test
    public void executeS3AssignmentOnEntry() {
        Response r = triggerEvent(instanceId, "anyEvent");
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        assertEquals("s3", json.getString("state"));

        Instance i = loadInstance(instanceId);
        i.assertState("s3");
        i.assertDatamodelElementExists("ticket", "price[. = '30']");
    }
}
