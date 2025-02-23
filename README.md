# ceph-ansible
Ansible을 사용하여 편히라게 Ceph 스토리지 클러스터를 배포, 관리, 정리

## 개요
- **목적**: Ceph 클러스터를 자동화된 방식으로 배포, 삭제 작업
- **도구**: Ansible, Cephadm, Docker.
- **지원 환경**: Ubuntu 기반 시스템, 3개 이상의 노드

## 요구사항
- Ansible 2.9 이상:
  ```bash
  sudo apt update
  sudo apt install ansible python3-pip
- Python 3.x.
- Docker 설치
  ```bash
  sudo apt install docker.io

## 구조
```text
CEPH-ANSIBLE/
├── group_vars/
│   ├── all.yml          # Ceph 배포 전역 변수
│   └── clean.yml        # Ceph 클러스터 정리 변수
├── inventory/
│   └── hosts.yml        # 호스트 및 그룹 정의
├── playbooks/
│   ├── deploy_ceph.yml  # Ceph 클러스터 배포 플레이북
│   └── clean_ceph.yml   # Ceph 클러스터 정리 플레이북
├── roles/
│   ├── bootstrap/       # Ceph 클러스터 부트스트랩 역할
│   │   └── tasks/
│   │       └── main.yml
│   ├── clean/           # Ceph 클러스터 정리 역할
│   │   └── tasks/
│   │       └── main.yml
│   ├── common/          # 공통 작업 역할 (패키지 설치 등)
│   │   └── tasks/
│   │       └── main.yml
│   ├── health_check/    # Ceph 클러스터 상태 점검 역할
│   │   └── tasks/
│   │       └── main.yml
│   └── services/        # Ceph 서비스 배포 역할
│       ├── tasks/
│       │   └── main.yml
│       └── templates/
│           ├── iscsi.yaml.j2
│           ├── nvmeof.yaml.j2
│           └── osd.yaml.j2
├── ansible.cfg          # Ansible 설정 파일
└── cephctl.sh           # Ceph 클러스터 관리 스크립트
```
## 설치 및 설정
- inventory/hosts.yml 노드 정보 수정
- group_vars/all.yml을 필요에 따라 수정. 예: ansible_user, ansible_ssh_pass, ceph.fsid, services 설정.

서비스 유형
group_vars/all.yml에서 정의된 서비스는 필수와 선택으로 구분

* 필수 서비스:
  * mon: 클러스터 상태 관리 (최소 3개 추천).
  * mgr: 관리 기능 및 대시보드 제공 (최소 2개 추천).
  * osd: 데이터 저장 (필수).

* 선택 서비스 (필요 시 빈 리스트로 설정 가능):
  * mds: CephFS(파일 스토리지) 사용 시 필요.
  * rgw: 객체 스토리지(S3/Swift) 사용 시 필요.
  * nfs: CephFS 기반 NFS 서버, 파일 스토리지 사용 시 필요 (MDS 의존).
  * rbd_mirror: 블록 스토리지 미러링 사용 시 필요.
  * iscsi: 블록 스토리지를 iSCSI로 제공 시 필요.
  * nvmeof: 고성능 블록 스토리지 사용 시 필요.
  * monitoring: 클러스터 상태 모니터링(Prometheus, Grafana 등) 시 필요.

## 사용 방법
cephctl.sh 스크립트를 사용하여 Ceph 클러스터를 관리
```bash
./cephctl.sh <옵션>
```

### 지원옵션
```bash
사용법: ./cephctl.sh [옵션]
옵션:
  deploy        : Ceph 클러스터 배포
  cleanup       : 컨테이너 및 설정 정리 (데이터 유지)
                  - OSD 디스크 데이터는 남지만, 새 클러스터에서 바로 사용하려면 FSID 유지 또는 OSD 복구 필요.
                  - 현재는 데이터 유지로 끝나며, 재사용은 추가 작업 필요.
                  - 재설치 시 기존 데이터 인식 여부는 추후 테스트가 필요함.
  cleanup-all   : 모든 데이터 완전 삭제 후 초기화
```
<b>1. 클러스터 배포</b>
```bash
./cephctl.sh deploy
```
```playbooks/deploy_ceph.yml``` 실행, Ceph 클러스터 배포 (MON, MGR, OSD 등 필수 서비스 포함).

<b>2. 삭제 (데이터 유지)</b>
```bash
./cephctl.sh cleanup
```
클러스터 설정과 서비스 제거, OSD 데이터 및 설정 파일(```/etc/ceph```, ```/var/lib/ceph/osd/*```) 유지.

<b>3. 삭제</b>
```bash
./cephctl.sh cleanup-all
```
모든 데이터와 설정(디스크 포함) 완전 삭제.


