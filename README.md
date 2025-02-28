# ceph-ansible
Ansible을 사용하여 **Ceph 스토리지 클러스터**를 쉽게 배포, 삭제할 수 있도록 자동화된 환경을 제공합니다.


## 개요
- **📌 목적**: Ceph 클러스터를 **자동화 방식으로 배포 및 삭제**  
- **🔧 사용 도구**: Ansible, Cephadm, Podman/Docker  
- **🖥️ 지원 환경**: Ubuntu 기반 시스템 (3개 이상의 노드 추천)  

## 참고
- **테스트 환경**: Ubuntu 24.04.1 LTS, Ceph v19.2.0  
  - **⚠️ 주의**: Ceph 버전에 따라 명령어가 다를 수 있음  
  - **🛠️ 해결 방법**: 서비스 배포 로직을 필요에 따라 수정  
- **주의사항**:  
  - `all_available_devices: true` 사용 시 루트 디스크(`/dev/sda`) 제외 확인  
  - `cluster_network` 설정이 노드 간 통신에 맞는지 점검  
- **추가 문서**:  
  - [Cephadm](https://docs.ceph.com/en/reef/cephadm/)  
  - [Cephadm-ansible](https://github.com/ceph/cephadm-ansible)

## 1️⃣ 요구사항
### 필수설치
```bash
apt-get update && apt-get install -y ansible sshpass podman
```
### App armor 비활성화 (모든 호스트)
```bash
systemctl disable apparmor
service apparmor stop
reboot
```
## 2️⃣ 프로젝트 구조
```text
CEPH-ANSIBLE/
├── inventory/
│   ├── group_vars/
│   │   ├── all.yml         # 모든 호스트에 적용되는 전역 변수
│   ├── hosts.ini           # INI 형식의 인벤토리 파일
│
├── playbooks/
│   ├── deploy.yml          # Ceph 클러스터 배포 플레이북
│   ├── clean.yml           # Ceph 클러스터 삭제 플레이북
│   ├── debug.yml           # 디버깅을 위한 테스트 플레이북
│   ├── roles/              # Ansible 역할(Role) 디렉토리
│   │   ├── bootstrap/      # Ceph 클러스터 초기 부트스트랩 역할
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   ├── common/         # 공통 작업 역할 (패키지 설치, 설정 등)
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   ├── health_check/   # Ceph 클러스터 상태 점검 역할
│   │   │   └── tasks/
│   │   │       └── main.yml
│   │   ├── services/       # Ceph 서비스 배포 역할
│   │   │   ├── tasks/
│   │   │   │   └── main.yml
│   │   │   ├── templates/  # 서비스 배포를 위한 Jinja2 템플릿
│   │   │   │   ├── iscsi.yaml.j2
│   │   │   │   ├── nvmeof.yaml.j2
│   │   │   │   └── osd.yaml.j2
│
├── ansible.cfg             # Ansible 설정 파일
├── cephctl.sh              # Ceph 클러스터 관리 스크립트
└── README.md               # 프로젝트 설명 파일
```
## 3️⃣ 설치 및 설정
### 1. /etc/hosts 파일 수정 (각 노드에서 동일하게 설정)
```bash
192.168.0.191 squid4
192.168.0.192 squid5
192.168.0.193 squid6
```

### 2. AppArmor 비활성화 (노드 전부)
```bash
systemctl disable apparmor
service apparmor stop
reboot
```

### 3. 배포 전 설정
####  `inventory/hosts.ini` : Ceph 클러스터에 포함될 노드 및 부트스트랩 노드를 설정
```ini
[all]
squid4 ansible_host=192.168.0.191
squid5 ansible_host=192.168.0.192
squid6 ansible_host=192.168.0.193

[bootstrap]
squid4
```
#### `group_vars/all.yml` : 배포할 Ceph 서비스 및 설정을 정의합니다.
```yaml
---
ansible_user: root
ansible_ssh_pass: squid

# 클러스터 배포 관련 설정
ceph:
  mon_ip: 192.168.0.191
  cluster_network: "10.0.4.0/24"
  version: "quay.io/ceph/ceph:v19.2.0"
  cephadm_version: "19.2.0"
  fsid: "fb2a0676-f439-11ef-82d7-080027b7bc18" # FSID 미지정 시 자동 생성  
  dashboard:
    init_password: "squid!@#$"

clean: # 클러스터 삭제시 사용
  fsid: "fb2a0676-f439-11ef-82d7-080027b7bc18"
  dirs:  # 삭제할 디렉토리 목록
    - /etc/ceph
    - /var/lib/ceph
    - /var/log/ceph
  packages:  # 삭제할 패키지 목록
    - ceph
    - ceph-mgr
    - ceph-mon
    - ceph-osd
    - ceph-mds    
    - cephadm
    - ceph-common

# 배포할 서비스 정의
services:
  # 필수 서비스: Ceph 클러스터의 기본 동작을 위해 반드시 배포해야 함

  mon:
    placement: "3"  # Monitor: 클러스터 상태 관리

  mgr:
    placement: "2"  # Manager: 관리 기능 및 대시보드 제공

  osd:
    #디바이스를 자동으로 osd로 활성화 할 경우 true, 특정 디스크를 사용하려면 false로 설정하고 devices 항목을 작성 (필수)
    all_available_devices: true 
    name: "osd.default"  # Object Storage Daemon: 데이터 저장, 필수
    hosts:
      - "squid4"
      - "squid5"
      - "squid6"
    devices:
      - "/dev/sdb"
      - "/dev/sdc"
      - "/dev/nvme0n1"
      - "/dev/nvme0n2"

  # 선택 서비스: 필요에 따라 배포, 사용하지 않을 경우 빈 리스트([])로 설정 가능  
  # Metadata Server: CephFS(파일 스토리지) 사용 시 필요
  mds:
    - name: "mds.default"
      placement: "3"
      pool:
        metadata: "cephfs_metadata"
        data: "cephfs_data"

  # RGW (RADOS Gateway) - 객체 스토리지(S3/Swift)

  rgw:
    - name: "rgw.default"
      placement: "3"
      pool: "rgw_data"
      realm: 
        name: "realm.default"   # RGW가 속할 Realm 이름
        default: true           # 기본 Realm으로 설정
      zonegroup: 
        name: "zonegroup.default"
        default: true           # 기본 Zonegroup 설정
        master: true            # 해당 Zonegroup의 Master 설정 (최소 1개 필요)
      zone: 
        name: "zone.default"
        master: true            # 해당 Zone의 Master 설정 (최소 1개 필요)
        default: true           # 기본 Zone으로 설정
      port: 7480                # RGW 서비스가 사용할 포트 (중복되지 않도록 설정)
    - name: "rgw.default2"
      placement: "3"
      pool: "rgw_data2"
      realm:
        name: "realm.default2"
      zonegroup:
        name: "zonegroup.default2"
      zone: 
        name: "zone.default2"
      port: 7481  # 두 번째 RGW 인스턴스, 포트 변경 필요 (7481)

  # NFS: CephFS 기반 NFS 서버, 파일 스토리지 사용 시 필요 (MDS 의존)
  nfs:
    - name: "nfs.default"
      placement: "3"
      pool: "cephfs_data"

  # RBD Mirror: 블록 스토리지 미러링 사용 시 필요
  rbd_mirror:
    - placement: "3"
      pool: "rbd_pool"

  # iSCSI Gateway: 블록 스토리지를 iSCSI로 제공 시 필요
  iscsi:
    - name: "iscsi.default"
      pool: "iscsi_pool"
      api_user: "iscsi_admin_user"
      api_password: "ceph!@#$"
      placement:
        hosts:
          - "squid4"
          - "squid5
          - "squid6"

  # NVMe over Fabrics: 고성능 블록 스토리지 사용 시 필요
  nvmeof: []

  # 모니터링 도구: 클러스터 상태 모니터링 시 필요
  monitoring:
    prometheus:
      placement: "1"
    grafana:
      api_url: "https://192.168.0.191:3000"
      placement: "1"
    alertmanager:
      placement: "1"
    node_exporter:
      placement: "*"
    crash:
      placement: "*"
```

### 📌 서비스 유형 정의 (`group_vars/all.yml`)  
Ceph의 서비스는 **필수 서비스**와 **선택 서비스**로 나뉩니다.  
아래 정의된 값은 `group_vars/all.yml`에서 설정  

---

### **🔹 필수 서비스 (클러스터 운영에 반드시 필요)**
| 서비스  | 설명 |
|---------|------|
| **MON (Monitor)** | 클러스터 상태 관리 (최소 3개 권장) |
| **MGR (Manager)** | 관리 기능 및 Ceph 대시보드 제공 (최소 2개 권장) |
| **OSD (Object Storage Daemon)** | 데이터 저장 (필수) |

#### **OSD 배포 옵션**
- `all_available_devices: true` → **모든 사용 가능한 디바이스를 자동으로 OSD로 배포** (디스크 목록 설정 불필요)
- `all_available_devices: false` → **지정한 devices 목록만 OSD로 사용** (명확한 디스크 지정 필요)  

```yaml
osd:
  all_available_devices: true  # true이면 모든 사용 가능한 디스크를 OSD로 설정
  hosts:
    - "squid4"
    - "squid5"
    - "squid6"
  devices:  # all_available_devices가 false일 때만 사용
    - "/dev/sdb"
    - "/dev/sdc"
    - "/dev/nvme0n1"
    - "/dev/nvme0n2" 
```

### **🔹 선택 서비스 (사용하지 않을 경우 빈 리스트 [] 설정 가능)**
2개 이상 동일한 서비스 배포시 별도의 포트 지정
| 서비스 | 설명 |
|--------|--------------------------------------------------|
| **📂 MDS (CephFS)** | CephFS(파일 스토리지) 사용 시 필요 |
| **🌐 RGW (RADOS Gateway)** | S3 및 Swift API를 제공하는 객체 스토리지 서비스 |
| **📡 NFS (Network File System)** | CephFS 기반 NFS 서버 (MDS 의존) |
| **🔄 RBD Mirror** | 블록 스토리지 미러링 (멀티 클러스터 환경에서 필요) |
| **🔗 iSCSI Gateway** | Ceph 블록 스토리지를 iSCSI로 제공 시 필요 |
| **🚀 NVMe-oF (NVMe over Fabrics)** | 고성능 블록 스토리지 |
| **📊 Monitoring** | Prometheus, Grafana 기반 모니터링 |

## 4️⃣ 사용 방법
### 실행 권한 부여
```bash
chmod +x cephctl.sh
```
### Ceph 클러스터 배포
`cephctl.sh` 스크립트를 사용하여 Ceph 클러스터를 배포 및 삭제
```bash
./cephctl.sh deploy
```
### Ceph 클러스터 삭제
```bash
./cephctl.sh cleanup

TASK [클러스터 삭제 확인 요청] ****************************************************************
[클러스터 삭제 확인 요청]
[경고] 클러스터 삭제를 진행합니다.
삭제할 FSID: fb2a0676-f439-11ef-82d7-080027b7bc18
⚠️ 이 작업은 되돌릴 수 없습니다.
계속 진행하려면 "yes"를 입력하세요.
:
yes
```


## 5️⃣ 트러블 슈팅
### 📌 osd 배포가 안되는경우 
```bash
TASK [services : osd 배포 실패] *************************************
fatal: [squid4]: FAILED! => {"changed": false, "msg": "⚠️ osd 배포 중 오류 발생! 로그를 확인하세요."}
```

1. 디스크 상태 확인

- `"REJECT REASONS"`에 `"Has a filesystem"`이 표시되면, 기존 파일 시스템이 존재하여 Ceph에서 사용하지 않는 상태
- `"AVAILABLE"`이 `"No"`로 되어 있으면 해당 디바이스를 OSD로 사용할 수 없음
```bash
root@squid4:~/ceph-ansible# cephadm shell -- ceph orch device ls
Inferring fsid fb2a0676-f439-11ef-82d7-080027b7bc18
Inferring config /var/lib/ceph/fb2a0676-f439-11ef-82d7-080027b7bc18/mon.squid4/config
Using ceph image with id '37996728e013' and tag 'v19.2.0' created on 2024-09-27 22:08:21 +0000 UTC
quay.io/ceph/ceph@sha256:200087c35811bf28e8a8073b15fa86c07cce85c575f1ccd62d1d6ddbfdc6770a
HOST    PATH          TYPE  DEVICE ID                               SIZE  AVAILABLE  REFRESHED  REJECT REASONS                                                         
squid4  /dev/nvme0n1  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid4  /dev/nvme0n2  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid4  /dev/sdb      hdd   ATA_VBOX_HARDDISK_VBca670075-a90f7e92  25.0G  Yes        6m ago                                                                            
squid4  /dev/sdc      hdd   ATA_VBOX_HARDDISK_VB53734388-019ba057  25.0G  Yes        6m ago                                                                            
squid4  /dev/sr0      hdd   VBOX_CD-ROM_VB0-01f003f6               1023M  No         6m ago     Failed to determine if device is BlueStore, Insufficient space (<5GB)  
squid5  /dev/nvme0n1  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid5  /dev/nvme0n2  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid5  /dev/sdb      hdd   ATA_VBOX_HARDDISK_VB9885d691-0cc5bf01  25.0G  Yes        6m ago                                                                            
squid5  /dev/sdc      hdd   ATA_VBOX_HARDDISK_VBf0b509d1-2d420635  25.0G  Yes        6m ago                                                                            
squid5  /dev/sr0      hdd   VBOX_CD-ROM_VB2-01700376               1023M  No         6m ago     Failed to determine if device is BlueStore, Insufficient space (<5GB)  
squid6  /dev/nvme0n1  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid6  /dev/nvme0n2  ssd   ORCL-VBOX-NVME-VER12_VB1234-56789      25.0G  Yes        6m ago                                                                            
squid6  /dev/sdb      hdd   ATA_VBOX_HARDDISK_VB3046362a-5fedd26f  25.0G  Yes        6m ago                                                                            
squid6  /dev/sdc      hdd   ATA_VBOX_HARDDISK_VB315e39f4-ff71492b  25.0G  Yes        6m ago                                                                            
squid6  /dev/sr0      hdd   VBOX_CD-ROM_VB2-01700376               1023M  No         6m ago     Failed to determine if device is BlueStore, Insufficient space (<5GB)  

```
2. 클러스터 삭제
```bash
./cephctl.sh cleanup
```

2. AppArmor 재확인
```bash
cat /sys/module/apparmor/parameters/enabled # Y인 경우

mkdir /etc/apparmor.d/disabled/
mv /etc/apparmor.d/MongoDB_Compass /etc/apparmor.d/disabled/
systemctl disable apparmor && service apparmor stop && reboot
```

3. 재배포
```bash
./cephctl.sh deploy
```

### 📌 특정 노드에서 삭제가 안되는 경우 (해당 노드 재부팅 후 수동으로 삭제)
1. 노드 재부팅
```bash
ssh root@<노드> "reboot"
```
2. Cephadm 다운로드 및 실행 권한 설정
```bash
curl -o /usr/sbin/cephadm https://download.ceph.com/rpm-{{ ceph.cephadm_version }}/el9/noarch/cephadm
chmod 755 /usr/sbin/cephadm
```
3. fsid dir 확인

해당 노드 fsid dir 확인(Ceph 클러스터의 고유 식별자)를 확인
```bash
root@squid5:~# ls -al /var/lib/ceph
total 12
drwxr-xr-x  3 root root 4096 Feb 27 10:58 .
drwxr-xr-x 47 root root 4096 Feb 27 04:36 ..
drwx------  8  167  167 4096 Feb 27 10:59 fb2a0676-f439-11ef-82d7-080027b7bc18
```

4. 클러스터 강제 삭제
```bash
cephadm rm-cluster --force --zap-osds --fsid "{{ clean.fsid }}"
```
---
사용하시면서 이슈나 개선 사항이 있으면 PR 또는 Amaranth로 공유 부탁드립니다! 🙌
