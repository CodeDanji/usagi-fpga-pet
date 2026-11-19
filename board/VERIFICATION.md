# 보드 통합 검증

검증 완료: 2026-11-19. Vivado/XSim 2024.2, `xc7s75fgga484-1`.
실물 보드 다운로드·LCD 촬영·카메라 인식 시험은 수행하지 않았다.

## 프로젝트와 산출물

- 프로젝트: `../final.xpr`, top `usagi_board_top`.
- 소스 15개(RTL 13개, MEM 2개), 활성 XDC 1개, 테스트벤치 4개 등록.
- 등록된 20개 파일 참조의 실제 존재를 확인했다. 임시 드라이브 경로 대신
  `$PSRCDIR` 상대 경로를 사용하고 프로젝트 헤더는 실제 C: 경로로 복원했다.
- 다운로드 파일: `usagi_lcd_learning.bit`, 3,686,923바이트.
- SHA256: `4e1b768f7d781a3213951e4c56b27fc605192965d15fcfd41f2517de74a7adc2`.
- 기능: LCD 우사기 표시, 버튼 표정 전환, 뉴런 3개와 시냅스 학습,
  수동 자극 및 9.9초 자동 조건반사 실험. 카메라 초기화는 포함하지 않는다.

## 시뮬레이션

`tb_board`에서 다음을 확인했다.

- 실제 UNISIM MMCM/BUFG/ODDR 모델과 리셋·lock 시작.
- A 버튼 입력/해제에 따른 표정 상태 전환.
- ROM 자극을 사용한 자동 학습 후 가중치 24 도달.
- 학습 중지 후 가중치 유지, 대조 자극 무반응과 학습 자극 반응.
- H 리셋 후 학습값 초기화.

최종 로그: `../experiments/results/board_run.log`의 `PASS board`.
`tb_display`의 두 표정 800x480 출력·픽셀 수·HS/VS 폭 검사도 통과했다.
뉴런 수치 모델과의 39,600단계 비교는 이전 독립 검증 결과를 참고한다.

## 실제 배치·배선 결과

| 항목 | 최종 결과 |
|---|---:|
| Setup WNS | +6.190ns |
| Hold WHS | +0.122ns |
| Pulse-width 여유 | +7.000ns |
| Setup / hold 실패 endpoint | 0 / 0 |
| LUT | 4,135 / 48,000 |
| FF | 528 / 96,000 |
| BRAM36 타일 | 12 / 90 |
| DSP | 13 / 140 |
| 고정 I/O | 45 |

`results/routed_timing.rpt`, `routed_utilization.rpt`, `routed_drc.rpt`에 원문을 보존했다.
`results/build.log`에서 `Bitgen Completed Successfully`, `BOARD BUILD COMPLETE`를 확인했다.
DRC 오류는 0개이고, 경고는 아래와 같이 남아 있다. 경고를 모두 제거한 설계라는 뜻은 아니다.

## 남은 경고와 실물 확인 사항

- **PLCK-12 1건:** 강의 보드의 G2 고정 클록 배선이 일반 I/O이므로 입력 IBUF부터
  첫 BUFG까지 일반 배선을 허용했다. 이후 MMCM/글로벌 클록을 사용한다.
  T2는 MRCC N측이어서 단일 종단 전용 클록 입력으로 사용할 수 없음을 DRC로 확인했다.
- **DPIP-1 24건:** 뉴런 DSP 입력을 파이프라인하지 않은 구조에 대한 성능 경고.
  현재 25MHz 목표에서는 배치·배선 타이밍을 만족했다.
- **PDRC-132/134/136/138 합계 12건:** LUT pair 배치·equation 관련 도구 경고가 남아 있다.
  원문을 숨기거나 심각도를 변경하지 않았다. 실물 검증을 대체하지 않는다.
- 스프라이트 ROM 출력과 자동 자극 ROM 주소의 리셋 경로를 정리해
  **REQP-1839 BRAM 비동기 제어 경고는 최종 보고서에서 없어졌다.**
- 도구 환경의 Tcl store/WebTalk 설정 쓰기 경고는 로그에 남아 있다.
  비트스트림 생성은 성공했다.

클록은 F=50MHz, LCD는 800x480과 falling-edge 샘플링을 기준으로 했다.
정확한 패널 porch와 보드 배선·전압은 실물에서 대조해야 한다.
카메라는 강의 PDF에 상세 핀맵·센서 초기화가 없어 기본 top에 연결하지 않았다.
시험 순서와 조작은 상위 `README.md`를 따른다.
