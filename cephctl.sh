#!/bin/bash

usage() {
  echo "Ceph 클러스터 배포/정리 스크립트"
  echo ""
  echo "사용법: $0 [옵션]"
  echo "옵션:"
  echo "  deploy        : Ceph 클러스터 배포"
  echo "  cleanup       : 컨테이너 및 설정 정리 (데이터 유지)"
  echo "                   - 데이터는 디스크에 물리적으로 남아 있지만, 새 클러스터에서 바로 사용하려면 FSID를 유지하거나 OSD 복구 작업이 필요합니다."
  echo "                   - 현재는 단순히 데이터 유지로 끝나며, 재사용은 추가 작업 필요."
  echo "  cleanup-all   : 모든 데이터 완전 삭제 후 초기화"
  echo ""
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

case "$1" in
  deploy)
    echo "Ceph 클러스터 배포"
    ansible-playbook inventory/hosts.yml playbooks/deploy_ceph.yml
    ;;
  cleanup)
    echo "Ceph 클러스터 정리 (데이터 유지)"
    ansible-playbook inventory/hosts.yml playbooks/clean_ceph.yml -e "wipe_data=false"
    ;;
  cleanup-all)
    echo "Ceph 클러스터 완전 삭제 및 초기화"
    ansible-playbook inventory/hosts.yml playbooks/clean_ceph.yml -e "wipe_data=true"
    ;;
  *)
    usage
    ;;
esac