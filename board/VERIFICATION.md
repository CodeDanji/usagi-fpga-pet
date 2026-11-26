# 카메라·LCD·학습 통합 결과

> **과거 G2 빌드 기록이다. 현재 실물 주클록은 B6로 확인됐다.**
> 아래 해시·타이밍·`board/usagi_camera_pet.bit`를 최신 B6 산출물로 간주하지 않는다.
> 사용자 실물 시험 파일은 `final.runs/impl_1/usagi_board_top.bit`이며,
> 현재 상태는 [인수인계서](../docs/HANDOFF.md)를 따른다.

2026-11-19, Vivado/XSim 2024.2, `xc7s75fgga484-1`.
**다운로드 파일: `usagi_camera_pet.bit`. 실물 보드 촬영·인식 시험은 아직 수행하지 않았다.**

## 산출물

- 프로젝트 `../final.xpr`, top `usagi_board_top`.
- RTL 16개, MEM 2개, XDC 1개, 테스트벤치 5개 및 Vivado utility DCP 등록.
  프로젝트 파일 참조 25개의 실제 존재를 확인했다. 소스는 `$PSRCDIR` 상대 경로다.
- BIT 3,686,923바이트, SHA256
  `1c7183d143703c6f6529515d947e0efe556b8b456704cc48270491517882936f`.
- 최종 로그 `results/implement.log`: `Bitgen Completed Successfully`,
  `BOARD IMPLEMENT COMPLETE`. 동일 RTL의 합성 체크포인트에 수정된 핀 XDC를 적용했다.
  최초 XDC의 반복문은 XDC 지원 범위에 맞춰 개별 핀 지정문으로 수정했다.
- 이전 LCD 전용 BIT는 보존했다. 이전 검증은 `backup/LCD_ONLY_VERIFICATION.md`에 보존했다.

## 동작과 확인 범위

사용자가 제공한 교재 사진의 OV7670 핀맵을 적용했다.
XCLK/RESET/PWDN, SCCB 초기화·ID/설정값 확인, VGA RGB565 수신,
전체 프레임 검사, 중앙 노란 카드 검출, 이중 버퍼 미리보기,
기존 버튼·ROM 자극·뉴런 학습을 하나의 top에 연결했다.

- `../experiments/results/camera_run.log`: `PASS camera`.
  SCCB 센서 모델과 전체 640x480 입력으로 초기화/읽기,
  잘못된 ID·미연결, 카드/대조 색, 불완전 프레임, 미리보기 첫·마지막 픽셀,
  버퍼 소유권, PCLK 중단 후 인식 해제, 컬러바 변경을 확인했다.
- `../experiments/results/board_run.log`: `PASS board`.
  UNISIM 클록·I/O 모델에서 버튼 반응, 자동 학습 후 가중치 24,
  가중치 유지·대조 자극·학습 자극 반응과 리셋을 확인했다.
- 이번에는 위 두 통합 경로만 실행했다. 개별 화면·수치 모델 등의 기존 시험은
  반복하지 않았다. 기본 `run_checks.ps1`도 이 두 경로로 한정했다.

## 배치·배선 결과

| 항목 | 결과 |
|---|---:|
| Setup WNS | +6.190ns |
| Hold WHS | +0.064ns |
| Pulse-width 여유 | +7.000ns |
| Setup / hold 실패 endpoint | 0 / 0 |
| LUT | 4,582 / 48,000 |
| FF | 1,205 / 96,000 |
| BRAM36 | 44 / 90 |
| DSP | 16 / 140 |
| 고정 I/O | 63 |

원문: `results/routed_timing.rpt`, `routed_utilization.rpt`, `routed_drc.rpt`,
`routed_cdc.rpt`. 모든 지정된 타이밍을 만족했고 BIT 생성 DRC 오류는 0개다.
아래 경고가 남으므로 모든 경고가 해소됐다는 뜻은 아니다.

## 남은 경고와 실물 확인

- PLCK-12 2건: 고정 G2 주클록, C6 카메라 PCLK가 일반 I/O다.
  각각 IBUF→첫 BUFG 구간만 일반 배선을 허용했다. 전용 클록 핀과 동등하지 않다.
- DPIP-1 25건, PDRC LUT pair 경고 5건: 최종 배선 타이밍은 만족했다.
- REQP-1839: BRAM 쓰기 허용이 비동기 assert 리셋의 영향을 받는 경고다.
  표시 제한에 따라 20건과 CHECK-3이 보고됐다. 전체 리셋에서는 preview_valid와
  소유권을 무효화하고 정상 프레임 전체를 다시 쓴 뒤에만 게시한다.
  리셋 중 메모리 내용 보존을 보장하는 구조는 아니다.
- CDC 요약 Unknown 1건은 published_bank→read_bank 전달이다.
  request 2단 동기화 후 LCD 공백에서 읽고 acknowledge까지 bank를 고정한다.
  25ns 최대 지연을 지정했다. Unsafe는 0이다. 프로토콜을 시뮬레이션으로 확인했으며
  도구가 전부 자동 판정한 것은 아니다.
- output delay 미지정 1포트는 전달 클록 CAM_XCLK다. LCD 데이터와 카메라 DVP
  입력 지연은 제약했다. SCCB는 저속 FSM으로 구동한다. 버튼·LED·리셋 등
  비동기 제어/표시는 별도 false path다. Tcl store 쓰기 경고는 도구 환경에 남아 있다.

실물에서는 CLOCK SELECT F=50MHz, DIP4 ON으로 미리보기·노란 카드 반응부터
확인한다. DIP5는 센서 내부 컬러바다. 조작은 `../README.md`, 핀·설정 근거는
`../docs/CAMERA_OV7670.md`를 따른다. LCD porch, 실제 색감·노출·배선 지연은
실물에서 확인해야 한다. JTAG 다운로드·플래시 쓰기는 실행하지 않았다.
