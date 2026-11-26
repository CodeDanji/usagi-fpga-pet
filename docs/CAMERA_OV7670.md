# 보드 카메라 근거와 연결

근거: 사용자가 2026-11-19 제공한 교재 p.652~653 사진.
센서 모델 OV7670, 모듈 공급전원 3.3V(모듈에 레귤레이터 내장).
아래 번호는 카메라 커넥터 순번이 아니라 **xc7s75fgga484 패키지 핀**이다.

| 신호 | FPGA 핀 | 신호 | FPGA 핀 |
|---|---|---|---|
| CAM_D0 | C9 | CAM_HREF | D6 |
| CAM_D1 | B8 | CAM_PCLK | C6 |
| CAM_D2 | C8 | CAM_PWDN | A9 |
| CAM_D3 | D8 | CAM_RESET | B9 |
| CAM_D4 | E8 | CAM_SIOD | A5 |
| CAM_D5 | A7 | CAM_SIOC | C5 |
| CAM_D6 | B7 | CAM_VSYNC | F6 |
| CAM_D7 | D7 | CAM_XCLK | A6 |

교재 회로: RESET/SIOD/SIOC 10kΩ 풀업, PWDN 풀다운.
SIOD는 FPGA IOBUF로 0 또는 high-Z를 출력한다. RESET은 low 활성,
PWDN은 0으로 유지한다. SIOC는 마스터 출력이다.
모든 포트는 보드의 3.3V 인터페이스에 맞춰 LVCMOS33을 지정했다.

Vivado 패키지 데이터베이스 조회 결과, C6은 `IO_L7P_T1_36` 일반 I/O다.
카메라 PCLK는 IBUF→BUFG로 수신하고 이 구간만 일반 배선을 허용한다.
현재 주클록은 사용자 실물 확인 결과 **B6**다. 강의 PDF의 G2는 이 보드에서 동작하지 않았다.
주클록을 G2로 되돌리지 않는다. 최신 상태는 [인수인계서](HANDOFF.md)를 따른다.
카메라 C6 경로는 배선 후 타이밍과 실물 수신 결과를 함께 확인해야 한다.
핀 조회 결과: `../board/results/package_pins.txt`.

## 센서 설정

[OmniVision OV7670 데이터시트 v1.01](https://www.olimex.com/Products/Components/Camera/CAMERA-OV7670/resources/OV7670.pdf)
pp.6~10의 클록 범위·출력 에지·RGB565·SCCB 주소와 레지스터 정의를 사용한다.
25MHz XCLK는 명시 범위 10~48MHz 안에 있다. CLKRC=1, PLL bypass 설정으로
센서 클록을 낮춘다. 입력 타이밍은 PCLK 25MHz, falling edge 이후 최대 7ns
(데이터시트 5ns와 보드 여유 2ns)로 보수적으로 제약했다.
이 수치는 실물 PCB 지연 측정 결과가 아니므로 실제 촬영 확인이 필요하다.

COM7=04(VGA/RGB), COM15=D0(full range/RGB565), COM3=00(byte swap 해제),
COM10=00(양의 HREF/VSYNC, blanking 중에도 PCLK), RGB444 해제.
자동 노출·게인·화이트밸런스를 켜고 300ms 안정화 시간을 둔다.
센서 ID 두 바이트 76/73과 COM7/COM15 읽기 결과가 맞아야 ready가 된다.
센서 초기화 실패를 가상 카메라 영상으로 대체하지 않는다.

VGA 윈도우와 RGB 색 행렬의 숫자는
[Linux upstream OV7670 드라이버](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov7670.c)의
센서 설정과 대조했다. 센서 제어 FSM과 SCCB RTL은 이 프로젝트에서 작성했다.
교재 모델명·핀맵은 확보했지만 이 보드 제조사에서 배포한 초기화 예제는 확보하지 못했다.
현재 설정은 데이터시트에 기반한 최초 실물 시험용이며 밝기·색감은 현장에서 조정할 수 있다.

## 데이터 경로

RGB565 상위 바이트 우선 → 전체 640x480 프레임 좌표 검증 → 중앙 ROI 색 검출.
프레임 보고는 handshake mailbox로 25MHz 뉴런 도메인에 전달한다.
노란색 임계값은 기존 `card_detector.sv`의 고정 기준이며 조명 불변 분류기가 아니다.
진입 35%, 해제 20%, 각각 3프레임 유지. 무수신 1초 후 카드/정상 상태 해제.

미리보기는 가로·세로 4배 간격으로 샘플링한 160x120 RGB565다.
두 BRAM 뱅크를 번갈아 사용한다. 쓰기가 끝난 정상 프레임만 게시하고,
LCD 수직 공백에서 뱅크를 교체·응답할 때까지 게시된 뱅크를 수정하지 않는다.
이 때문에 일부 카메라 프레임은 건너뛰지만 미리보기 한 프레임의 일관성을 유지한다.
실시간 색 검출은 미리보기의 프레임 생략과 독립적으로 모든 입력 프레임을 처리한다.

SCCB 클록은 약 99kHz. OV7670의 clock stretching은 사용하지 않는다.
정해진 길이의 전송 후 응답이 없으면 오류로 종료하며 무한 대기하지 않는다.
