# Global argument for the module to build
ARG MODULE=spring-petclinic-api-gateway
ARG PORT=8080

# Stage 1: Build the application using Maven
FROM maven:3.8.5-openjdk-17-slim AS build
ARG MODULE
WORKDIR /app
COPY . .
RUN mvn -pl $MODULE -am -DskipTests package

# Stage 2: Extract layers
FROM eclipse-temurin:17 AS builder
ARG MODULE
WORKDIR /application
COPY --from=build /app/${MODULE}/target/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

# Stage 3: Final runtime image
FROM eclipse-temurin:17
WORKDIR /application

# Port configuration
ARG PORT
ENV SERVER_PORT=${PORT}
EXPOSE ${PORT}

ENV SPRING_PROFILES_ACTIVE=docker

COPY --from=builder /application/dependencies/ ./
RUN true
COPY --from=builder /application/spring-boot-loader/ ./
RUN true
COPY --from=builder /application/snapshot-dependencies/ ./
RUN true
COPY --from=builder /application/application/ ./
RUN true

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
