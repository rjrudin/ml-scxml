package com.marklogic.scxml;

import static com.jayway.restassured.RestAssured.basic;

import org.junit.Before;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestExecutionListeners;

import com.jayway.restassured.RestAssured;
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
}
