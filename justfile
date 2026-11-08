default:
    @just --list

dev:
    ./script/dev.sh --run

dev-build:
    ./script/dev.sh --build

run:
    ./script/build_and_run.sh

stage:
    ./script/build_and_run.sh --stage

package:
    ./script/build_and_run.sh --package

verify:
    ./script/build_and_run.sh --verify

test:
    swift test --jobs "${SWIFT_JOBS:-2}" --scratch-path "${SWIFT_SCRATCH_PATH:-Local/swift-test}"

icon:
    ./script/build_icon.sh

install:
    ./script/install.sh
