package com.marklogic.scxml;

import static com.jayway.restassured.RestAssured.basic;
import static com.jayway.restassured.RestAssured.get;
import static com.jayway.restassured.RestAssured.post;

import java.util.List;

import org.junit.Before;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestExecutionListeners;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.path.json.JsonPath;
import com.jayway.restassured.response.Response;
import com.marklogic.clientutil.DatabaseClientConfig;
import com.marklogic.clientutil.spring.BasicConfig;
import com.marklogic.junit.NamespaceProvider;
import com.marklogic.junit.spring.AbstractSpringTest;
import com.marklogic.junit.spring.ModulesLoaderTestExecutionListener;
import com.marklogic.junit.spring.ModulesPath;
import com.marklogic.junit.spring.ModulesPaths;

@ContextConfiguration(classes = { BasicConfig.class })
@TestExecutionListeners(value = { ModulesLoaderTestExecutionListener.class })
@ModulesPaths(paths = { @ModulesPath(baseDir = "src/main/ml-modules"), @ModulesPath(baseDir = "src/test/ml-modules") })
public abstract class AbstractScxmlTest extends AbstractSpringTest {

    protected final static String SERVICE_PATH = "/v1/resources/scxml";

    private static boolean restAssuredInitialized = false;

    @Before
    public void initializeRestAssured() {
        if (!restAssuredInitialized) {
            logger.info("Initializing RestAssured...");

            DatabaseClientConfig config = getApplicationContext().getBean(DatabaseClientConfig.class);
            RestAssured.baseURI = "http://" + config.getHost();
            RestAssured.port = config.getPort();
            RestAssured.authentication = basic(config.getUsername(), config.getPassword());

            logger.info("RestAssured URI: " + RestAssured.baseURI);
            logger.info("RestAssured port: " + RestAssured.port);

            restAssuredInitialized = true;
        }
    }

    @Override
    protected NamespaceProvider getNamespaceProvider() {
        return new ScxmlNamespaceProvider();
    }

    protected String startMachineWithId(String machineId) {
        Response r = postToService("rs:machineId=" + machineId);
        assertTrue(r.getContentType().startsWith("application/json"));
        return r.jsonPath().getString("instanceId");
    }

    protected Response triggerEvent(String instanceId, String event) {
        return postToService(format("rs:instanceId=%s&rs:event=%s", instanceId, event));
    }

    protected Response postToService(String querystring) {
        Response r = post(SERVICE_PATH + "?" + querystring);
        try {
            assertEquals(200, r.getStatusCode());
            return r;
        } catch (AssertionError ae) {
            logger.error("Expected response to have 200 as a status code: " + r.asString());
            throw ae;
        }
    }

    protected Instance loadInstance(String instanceId) {
        Response r = get(SERVICE_PATH + "?rs:instanceId=" + instanceId);
        assertEquals(200, r.getStatusCode());
        assertTrue(r.getContentType().startsWith("application/xml"));
        return new Instance(parse(r.asString()));
    }

    protected void assertResponseHasInstanceIdAndState(Response r, String instanceId, String... states) {
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        List<String> stateList = json.getList("active-states", String.class);
        for (String state : states) {
            assertTrue(format("Did not find expected state %s in active-states: " + states, state),
                    stateList.contains(state));
        }
    }
}
