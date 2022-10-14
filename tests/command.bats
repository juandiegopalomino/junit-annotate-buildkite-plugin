#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to get debug output from each stub
# export MKTEMP_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty
# export DU_STUB_DEBUG=/dev/tty

export artifacts_tmp="tests/tmp/junit-artifacts"
export annotation_tmp="tests/tmp/junit-annotation"


@test "runs the annotator and creates the annotation" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_FAIL_BUILD_ON_ERROR=false

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4" \
    "annotate --context \* --style \* : cat >'${annotation_tmp}/annotation.input'; echo Annotation added with context \$3 and style \$5, content saved"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env \* --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo '<details>Failure</details>' && exit 64"

  run "$PWD/hooks/command"

  assert_success

  assert_output --partial "Annotation added"
  
  unstub mktemp
  unstub buildkite-agent
  unstub docker
}

@test "returns an error if fail-build-on-error is true" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_FAIL_BUILD_ON_ERROR=true

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4" \
    "annotate --context \* --style \* : cat >'${annotation_tmp}/annotation.input'; echo Annotation added with context \$3 and style \$5, content saved"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env \* --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo '<details>Failure</details>' && exit 64"

  run "$PWD/hooks/command"

  assert_failure

  unstub mktemp
  unstub buildkite-agent
  unstub docker
}

@test "can pass through optional params" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_JOB_UUID_FILE_PATTERN="custom_(*)_pattern.xml"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_FAILURE_FORMAT="file"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_FAIL_BUILD_ON_ERROR=false
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_CONTEXT="junit_custom_context"

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4" \
    "annotate --context \* --style \* : cat >'${annotation_tmp}/annotation.input'; echo Annotation added with context \$3 and style \$5, content saved"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env BUILDKITE_PLUGIN_JUNIT_ANNOTATE_JOB_UUID_FILE_PATTERN='custom_(*)_pattern.xml' --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo '<details>Failure</details>' && exit 64"

  run "$PWD/hooks/command"

  assert_success

  assert_output --partial "Annotation added"

  unstub mktemp
  unstub buildkite-agent
  unstub docker
}

@test "doesn't create annotation unless there's failures" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env \* --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo No test errors"

  run "$PWD/hooks/command"

  assert_success

  unstub mktemp
  unstub buildkite-agent
  unstub docker
}

@test "errors without the 'artifacts' property set" {
  run "$PWD/hooks/command"

  assert_failure

  assert_output --partial "BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS: unbound variable"
}

@test "fails if the annotation is larger than 1MB" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  # 1KB over the 1MB size limit of annotations
  stub du \
    "-k \* : echo 1025 \$2"

  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env \* --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo '<details>Failure</details>' && exit 64"

  run "$PWD/hooks/command"

  assert_success

  assert_output --partial "Failures too large to annotate"

  unstub docker
  unstub buildkite-agent
  unstub du
  unstub mktemp
}

@test "returns an error if fail-build-on-error is true and annotation is too large" {
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_ARTIFACTS="junits/*.xml"
  export BUILDKITE_PLUGIN_JUNIT_ANNOTATE_FAIL_BUILD_ON_ERROR=true

  stub mktemp \
    "-d \* : mkdir -p '$artifacts_tmp'; echo '$artifacts_tmp'" \
    "-d \* : mkdir -p '$annotation_tmp'; echo '$annotation_tmp'"

  # 1KB over the 1MB size limit of annotations
  stub du \
    "-k \* : echo 1025 \$2"
  
  stub buildkite-agent \
    "artifact download \* \* : echo Downloaded artifact \$3 to \$4"

  stub docker \
    "--log-level error run --rm --volume \* --volume \* --env \* --env \* --env \* ruby:2.7-alpine ruby /src/bin/annotate /junits : echo '<details>Failure</details>' && exit 64"

  run "$PWD/hooks/command"

  assert_failure

  assert_output --partial "Failures too large to annotate"

  unstub mktemp
  unstub buildkite-agent
  unstub docker
}