# Local workflow rules for this repo (not committed; linked by bootstrap)

Stack: spring. Build tool: <maven|gradle>. Java: 21. Base branch: develop.
Build: `mvn -q -DskipTests -Dmaven.compiler.failOnWarning=true compile`
(Gradle: `gradle compileJava` with `-Werror`). Lint: <Checkstyle or Error Prone goal>.
Format: `mvn spotless:check`. Test: `mvn test` (JaCoCo coverage floor: <n>%).
Mutation: `mvn org.pitest:pitest-maven:mutationCoverage -DtargetClasses=<changed package>.*`.
Run: `mvn spring-boot:run -Dspring-boot.run.profiles=<local profile>` on port <n>.
Health: `curl -fsS http://localhost:<n>/actuator/health`. Test doubles: H2 for the database,
WireMock for <outbound services>.
Evidence path: programmes/<programme>/verify/<JIRA>/.
Repo-specific notes: <anything the team's CLAUDE.md does not say>.
