# 우사기 FPGA 보드 시험 프로젝트

**열 프로젝트: `final.xpr` / Design Sources top: `usagi_board_top`.**
RTL, ROM, XDC와 테스트벤치를 Vivado 표준 `final.srcs` 아래에 배치하고 실제 프로젝트에 등록했다.
`.sv`는 Vivado가 지원하는 SystemVerilog 소스이며, 파일 유형도 명시했다.

최종 배치·배선/비트스트림 결과와 남은 경고는 [보드 검증 결과](board/VERIFICATION.md)에 정리했다.

## 지금 열린 Sources가 비어 있는 경우

외부에서 수정한 `.xpr`는 실행 중인 GUI의 목록을 자동으로 바꾸지 않는다.
현재 `final` 프로젝트의 **Tcl Console**에서 아래 한 줄을 실행하면 현재 창에 직접 등록된다.

```tcl
source {C:/Users/sodas/.Xilinx/final/scripts/register_project.tcl}
```

또는 `final.xpr`를 다시 연다. 단순히 `.sv`를 디스크에 저장하는 것과 프로젝트 등록을 구분했다.

## 다운로드할 파일과 기능

`board/usagi_camera_pet.bit`는 **OV7670 카메라 + TFT LCD + 실제 뉴런/학습 회로** 통합 시험용이다.
128x128 4비트 우사기 두 표정, MMCM 클록 생성, LCD 픽셀 클록 출력,
핀·I/O 표준·LCD 입출력 타이밍 제약을 포함한다.

사용자가 제공한 교재 p.652~653 사진의 OV7670 모델명·핀맵을 적용했다.
센서 RESET/XCLK, SCCB 설정·ID/설정값 읽기 검증, VGA RGB565 수신,
중앙 노란 카드 검출, 160x120 이중 버퍼 미리보기(화면에서는 320x240)를 포함한다.
예전 `usagi_lcd_learning.bit`는 카메라가 없는 이전 버전이므로 새 파일을 선택한다.

## 보드에서 시험하기

1. Xilinx Spartan-7 모듈을 사용한다. 대상 부품은 `xc7s75fgga484-1`이다.
2. 보드의 **CLOCK SELECT 스위치를 F(50MHz)**로 둔다.
   이 설계는 강의 핀맵의 `MAIN_CLOCK1 = G2`를 사용한다.
   G2는 일반 I/O이므로 첫 글로벌 버퍼까지 일반 배선을 허용하고 이후 MMCM/BUFG를 사용한다.
   T2는 MRCC의 N측이라 단일 종단 전용 클록 입력으로 사용할 수 없음을 배치 DRC로 확인했다.
3. DIP1~5를 모두 OFF로 두고 JTAG를 연결한다.
4. Vivado Hardware Manager에서 Open Target / Auto Connect 후 FPGA의 Program Device를 누르고
   `board/usagi_camera_pet.bit`를 선택한다. 또는 다음 Tcl을 **직접 실행**한다.

   ```tcl
   source {C:/Users/sodas/.Xilinx/final/scripts/program_board.tcl}
   ```

5. **H 버튼**을 눌렀다 놓아 초기화한다. LED1(아래 표의 LED[0])은 클록 lock,
   LED2는 느린 점멸이며 우사기가 LCD에 표시되어야 한다.
6. **A 버튼**을 누르면 기쁜 표정, 놓으면 기본 표정이다. B 버튼도 먹이 반응을 낸다.

### 실제 카메라부터 확인하기

1. 보드 전원을 끈 상태에서 교재의 카메라 커넥터에 OV7670 모듈을 연결한다.
   전원을 켜고 통합 BIT를 다운로드한 뒤 DIP4만 ON으로 둔다. H를 눌렀다 놓는다.
2. 약 0.5초 이상 기다린다. LCD 위쪽 네 번째 상자는 초기화 중 주황,
   ID `0x7673`와 RGB 설정 읽기 확인 후 초록, 통신/ID/설정 오류 시 빨강이다.
3. 왼쪽 미리보기에 실제 영상이 나오면 가운데 노란 사각형 안에 노란 카드를 댄다.
   중앙 320x240 ROI 중 노란색 35% 이상이 3프레임 유지되면 우사기가 반응한다.
   해제 기준은 20% 미만 3프레임이다. 파란 카드는 같은 반응이 없어야 한다.
   영상 중단 1초 후 인식은 해제된다. 프레임 전체가 640x480이어야 유효하다.
4. 영상이 이상하면 DIP5를 ON으로 바꾼다. 센서를 재초기화하여 **센서 내부 컬러바**를 출력한다.
   OFF로 돌리면 실제 촬영으로 재초기화한다. 컬러바에서는 색 인식을 평가하지 않는다.
5. DIP1·DIP2·DIP4 ON, DIP3·DIP5 OFF로 두면 카메라 카드 입력과 B 먹이 버튼을
   실제 학습 회로에 넣을 수 있다. 노란 카드를 먼저 보여 주고 B를 함께 누르는 짝짓기를
   여러 차례 반복한다. DIP2 OFF 후 카드만 제시해 학습 전후 반응을 비교한다.
   이때 A는 카메라 대신 사용되지 않는다. DIP3 ON은 ROM 자극이 우선한다.

카메라 모드의 LED1~8: **lock / 점멸 / 카드 / 뉴런 반응 / 프레임 수신 /
정상 크기 프레임 / 센서 설정 완료 / 센서 오류**.
LCD 위쪽 왼쪽 세 상자는 수신 / 정상 프레임 / 표정 반응이며, 아래 노란 막대는
직접 모드에서 ROI 노란 픽셀 비율, 뉴런 모드에서 학습 가중치를 표시한다.
하단 y=440의 첫 16비트는 센서 ID(LSB부터), 다음 4비트는 오류 코드다.
오류 1=SCCB NACK, 2=ID 불일치, 3=RGB 설정 읽기 불일치. 오류 후에는 H로 재시도한다.
H는 학습값도 지운다. DIP5 변경은 카메라만 재초기화한다.

### 조건반사 자동 실험

1. DIP1, DIP2, DIP3을 모두 ON으로 두고 H를 눌렀다 놓는다.
2. 약 **9.9초** 동안 학습 전 자극, 카드/먹이 8회 짝짓기, 학습 후 자극과 대조 색 시험을 실행한다.
   센서 대신 FPGA 내부 ROM의 동일 자극 순서를 사용한다. 소프트웨어에서 대신 계산하는 것이 아니다.
3. DIP1은 ON으로 두고 DIP2와 DIP3을 OFF로 바꾼다. 1초 이상 기다린다.
4. A(학습 색)를 누르면 기대 반응이 생기고, C(대조 색)는 같은 반응을 만들지 않아야 한다.
5. H를 눌러 학습값을 지운 뒤, 같은 설정에서 A를 눌러 학습 전후를 비교한다.

### 직접 학습

DIP1·DIP2 ON, DIP3 OFF로 둔다. A를 누른 상태에서 잠시 후 B를 함께 누르고 놓는 동작을 반복한다.
이후 DIP2를 OFF로 바꿔 학습을 멈추고 A만 눌러 반응을 비교한다. C는 대조 입력이다.
카드만 제시했을 때 실제 먹이를 준 것으로 처리하지 않는다.

| 조작 | 의미 |
|---|---|
| DIP1 OFF | LCD·버튼 직접 반응 모드 |
| DIP1 ON | 뉴런 반응 모드 |
| DIP2 ON | 뉴런 모드에서 학습 허용 |
| DIP3 ON | 뉴런 모드에서 자동 자극 시퀀스 |
| DIP4 ON | A 대신 실제 카메라 노란 카드 사용, 미리보기 표시 |
| DIP5 ON | OV7670 내부 컬러바; 변경 시 카메라 재초기화 |
| A / B / C | 학습 색 / 먹이 / 대조 색 |
| H | 전체 초기화: 클록·화면·가중치 포함 |

| 보드 표시 | 의미 |
|---|---|
| LED1 / LED[0] | MMCM lock |
| LED2 / LED[1] | 동작 점멸 |
| LED3 / LED[2] | 학습 색 자극 |
| LED4 / LED[3] | 먹이 자극 |
| LED5 / LED[4] | 출력 뉴런 반응을 약 200ms 연장 표시 |
| LED6 / LED[5] | 학습 가중치가 0보다 큼 |
| LED7 / LED[6] | 수치 클리핑: 정상 시험에서는 꺼져 있어야 함 |
| LED8 / LED[7] | 현재 학습 허용 |
| LCD 노란 막대 | 직접 모드: A 입력 / 뉴런 모드: 가중치 0~24 |
| LCD y=408 비트열 | 뉴런 모드: 왼쪽 8비트 가중치, 오른쪽 8비트 발화 수 / 직접 모드: 프레임 수 |

## 파일 위치

```text
final.xpr
final.srcs/
  sources_1/rtl/board/      보드 top, MMCM, 학습 실험 실행기
  sources_1/rtl/common/     리셋·클록 간 전달
  sources_1/rtl/display/    LCD 타이밍·스프라이트
  sources_1/rtl/neuron/     고정소수점 뉴런·학습 회로
  sources_1/rtl/vision/     카메라 수신·색 검출·가상 센서
  sources_1/rom/            스프라이트·자동 실험 자극 MEM
  constrs_1/new/            활성 핀·타이밍 XDC
  sim_1/new/                보드·카메라·화면·카드·학습 테스트벤치
board/                     다운로드용 BIT·검증 보고서·원본 XPR 백업
scripts/                   Vivado 등록·빌드·수동 다운로드 스크립트
experiments/               기준 모델·자산 생성기·이전 실험 설명
```

기존 `experiments/rtl`, `sim`, ROM 위치에서 **이동**했으며 이중으로 편집할 소스를 남기지 않았다.
이전 실험 실행 스크립트도 새 위치를 참조한다.

## 다시 빌드·시뮬레이션하기

PowerShell에서 작업 폴더 기준으로:

```powershell
& ./scripts/vivado.ps1 -Action setup
& ./scripts/vivado.ps1 -Action simulate
& ./scripts/vivado.ps1 -Action build
```

`build`는 프로젝트와 같은 RTL/XDC를 단일 Vivado 프로세스에서 합성·배치·배선하여 BIT를 만든다.
이 환경에서 Windows WSH Run 실행기가 시작되지 않는 문제를 피한다. 정상적인 로컬 GUI에서는
프로젝트의 Generate Bitstream도 같은 top과 XDC를 사용한다.
Tcl/숨김 경로 문제를 피하기 위한 임시 드라이브는 실행 후 해제하고 `.xpr` 헤더는 실제 경로로 복원한다.
빌드 도중 같은 프로젝트에서 다른 빌드를 동시에 실행하지 않는다.

기본 Run Simulation은 `sim_1 / tb_board`다. 다른 실험은 Simulation Sources의
`sim_card`, `sim_display`, `sim_conditioning`을 활성화해 실행한다.
`sim_camera / tb_camera`는 실제 SCCB 신호를 처리하는 센서 모델과 전체 640x480 DVP 프레임으로
초기화·수신·검출·미리보기·오류 처리를 검증한다. PowerShell 실행:

```powershell
& ./experiments/scripts/run_checks.ps1 -Task camera
```

## 근거와 실물 확인 범위

핀은 강의 PDF의 p.5/8/11/15/76을 사용했다. 버튼 회로(p.11~12)는 눌렀을 때 HIGH다.
카메라 핀은 [교재 사진에서 옮긴 핀맵과 설정 근거](docs/CAMERA_OV7670.md)를 사용한다.
LCD는 p.72의 800x480 RGB888, p.73의 falling-edge 샘플링을 기준으로 구성했다.
제조사 [공식 카탈로그](https://hanback.com/wp-content/uploads/2019/03/FPGA-Digital-Logic-Design_e.pdf)도
800x480을 명시한다. 실제 패널의 porch 값이 다르면 `lcd_timing.sv`를 조정해야 한다.
LVCMOS33은 강의의 3.3V 논리 회로를 기준으로 한다.
G2의 고정 핀 배선을 유지하기 위한 입력 버퍼 구간의 일반 배선 허용은
[AMD UG903](https://docs.amd.com/r/2024.1-English/ug903-vivado-using-constraints/CLOCK_DEDICATED_ROUTE)에
설명된 방법이다. 이 입력 경로는 전용 클록 핀과 동등하다고 간주하지 않는다.

BIT 생성·DRC·타이밍 결과와 실물 LCD 촬영/카메라 시험은 구분한다.
클록 lock과 버튼 LED는 정상인데 화면만 깨지면 먼저 LCD 타이밍·DCLK 샘플링 에지를 대조한다.
현재 보드가 연결되지 않은 상태에서는 LCD가 실제로 켜졌다고 보고하지 않는다.
