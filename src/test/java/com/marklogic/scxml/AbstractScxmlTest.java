package com.marklogic.scxml;

import static com.jayway.restassured.RestAssured.basic;
import static com.jayway.restassured.RestAssured.get;
import static com.jayway.restassured.RestAssured.post;

import org.junit.Before;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestExecutionListeners;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.client.helper.DatabaseClientConfig;
import com.marklogic.test.jdom.NamespaceProvider;
import com.marklogic.test.spring.AbstractSpringTest;
import com.marklogic.test.spring.BasicTestConfig;
import com.marklogic.test.spring.ModulesLoaderTestExecutionListener;
import com.marklogic.test.spring.ModulesPath;
import com.marklogic.test.spring.ModulesPaths;

@ContextConfiguration(classes = { BasicTestConfig.class })
@TestExecutionListeners(value = { ModulesLoaderTestExecutionListener.class })
@ModulesPaths(paths = { @ModulesPath(baseDir = "src/main/xqy"), @ModulesPath(baseDir = "src/test/xqy") })
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
        assertEquals("application/json", r.getContentType());
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
            logger.error(r.asString());
            throw ae;
        }
    }

    protected Instance loadInstance(String instanceId) {
        Response r = get(SERVICE_PATH + "?rs:instanceId=" + instanceId);
        assertEquals(200, r.getStatusCode());
        assertEquals("application/xml", r.getContentType());
        return new Instance(parse(r.asString()));
    }
}
