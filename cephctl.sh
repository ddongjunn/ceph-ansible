#!/bin/bash

usage() {
  echo "Ceph 클러스터 배포/정리 스크립트"
  echo ""
  echo "사용법: $0 [옵션]"
  echo "옵션:"
  echo "  deploy    : Ceph 클러스터 배포"
  echo "  cleanup   : 모든 데이터 완전 삭제 후 초기화"
  echo ""
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

case "$1" in
  "deploy")
    echo "Ceph 클러스터 배포"
    ansible-playbook playbooks/deploy.yml
    ;;
  "cleanup")
    echo "Ceph 클러스터 완전 삭제 및 초기화"
    ansible-playbook playbooks/clean.yml -e "wipe_data=false"
    ;;
  *)
    usage
    ;;
esac