# syntax=docker/dockerfile:1

# -------------------------------------------------------------------------
# Stage 1: Runtime image for the runnable JAR
# -------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

# Create a non-root user/group to run the application.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Working directory owned by appuser.
WORKDIR /app
RUN chown -R appuser:appgroup /app

# Copy the versioned JAR from the build context.
# The CI pipeline renames the artifact to myapp-<version>.jar before building the image.
ARG JAR_FILE=myapp.jar
COPY --chown=appuser:appgroup ${JAR_FILE} app.jar

# Switch to the non-root user.
USER appuser

# Run the JAR.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
