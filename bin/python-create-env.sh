# shellcheck shell=bash

ENV_DIR="$HOME/.venv"
ENVIRONMENT_NAME=${NAME:-base}

help() {
  echo "Usage: source python-env.sh [-p python_version]"
  echo
  echo "Options:"
  echo "  -v    Specify the Python version to use (default: 3.8)"
  echo
}
while getopts "v:n:h" opt; do
  case ${opt} in

    d )
      ENV_DIR=$OPTARG
      ;;
    v  )
      PYTHON_VERSION=$OPTARG
      ;;
    n )
      NAME=$OPTARG
      ;;
    h )
      help
      exit 0
      ;;
    \? )
      echo "Usage: cmd [-p python_version]"
      exit 1
      ;;
  esac
done

# Set default Python version if not provided
PYTHON_VERSION=${PYTHON_VERSION:-3.14}

# pushd "$HOME" || exit 1

# check if .venv directory exists, create if not
if [ ! -d "$HOME/.venv" ]; then
  echo "Creating Python virtual environment '$ENVIRONMENT_NAME' with Python $PYTHON_VERSION..."
  uv venv --seed --python "$PYTHON_VERSION" "$HOME"/"$PYTHON_VERSION"-"$(arch)"-"$ENVIRONMENT_NAME"
else
  if [ ! -d "$HOME/.venv/$PYTHON_VERSION-$(arch)-$ENVIRONMENT_NAME" ]; then
    echo "Creating Python virtual environment with Python $PYTHON_VERSION..."
    uv venv --seed --python "$PYTHON_VERSION" "$HOME"/"$PYTHON_VERSION"-"$(arch)"-"$ENVIRONMENT_NAME"
  else
    echo "Python virtual environment '$ENVIRONMENT_NAME' already exists for Python $PYTHON_VERSION."
  fi
fi
