package com.frcalderon.shiftplanner;

import static org.assertj.core.api.Assertions.assertThat;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationState;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.client.RestTestClient;

@IntegrationTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class ShiftPlannerApplicationIT {

	@Autowired
	private RestTestClient client;

	@Autowired
	private Flyway flyway;

	@Test
	void applicationStartsAndReportsHealthy() {
		client.get().uri("/actuator/health")
				.exchange()
				.expectStatus().isOk()
				.expectBody()
				.jsonPath("$.status").isEqualTo("UP")
				.jsonPath("$.components.db.status").isEqualTo("UP");
	}

	@Test
	void flywayMigrationsAreApplied() {
		assertThat(flyway.info().pending()).isEmpty();
		assertThat(flyway.info().applied())
				.isNotEmpty()
				.allSatisfy(migration -> assertThat(migration.getState()).isEqualTo(MigrationState.SUCCESS));
	}

}
