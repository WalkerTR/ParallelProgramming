if [ -z "$CHPL_HOME" ]; then
  cd /home/hphijma/chapel-1.14.0/
  source util/setchplenv.bash
  cd -
  export CHPL_TARGET_ARCH="native"
fi

