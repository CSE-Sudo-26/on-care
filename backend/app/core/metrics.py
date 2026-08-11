"""인프로세스 카운터 — AI 경로가 조용히 죽는 것을 보이게 한다(#583).

배경: 루틴 생성도 식단 추천도 어떤 실패든 규칙 기반으로 조용히 폴백한다. 사용자는
그럴듯한 결과를 계속 받으므로 아무도 신고하지 않고, 로그는 요청마다 한 줄씩 흘러가
"요즘 AI 가 도는가?" 를 답해 주지 못한다. 실제로 그 때문에 루틴 생성이 상시 폴백인
상태가 오래 방치됐다(#579).

여기서 하는 일은 최소한이다 — 성공/폴백 횟수와 사유, LLM 소요 시간의 합·최댓값.
`GET /system/metrics`(관리자 전용)로 읽는다.

**단일 인스턴스/데모 기준이다.** 값은 프로세스 메모리에 있고 재시작하면 사라지며,
여러 인스턴스로 늘리면 각자 자기 몫만 센다. 운영으로 갈 때는 Prometheus 나 StatsD
로 교체한다(#480 배포와 함께 볼 문제).
"""
from __future__ import annotations

import threading

#: 라벨 조합당 한 칸. 카디널리티가 낮은 라벨(reason/by)만 쓴다 — user_id 같은 값을
#: 라벨로 넣으면 이 딕셔너리가 사용자 수만큼 자란다.
_counters: dict[str, int] = {}

#: key -> (관측 횟수, 합계 ms, 최댓값 ms). 개별 값을 모아 두지 않는 이유는 같다 —
#: 요청마다 리스트가 자라면 메모리가 단조 증가한다.
_durations: dict[str, tuple[int, float, float]] = {}

_lock = threading.Lock()


def _key(name: str, labels: dict[str, str]) -> str:
    if not labels:
        return name
    # 정렬해야 같은 라벨 조합이 순서와 무관하게 한 칸을 쓴다.
    inner = ",".join(f"{k}={labels[k]}" for k in sorted(labels))
    return f"{name}{{{inner}}}"


def incr(name: str, /, **labels: str) -> None:
    """카운터를 1 올린다. 계측 실패가 기능을 깨뜨리면 안 되므로 예외를 내지 않는다."""
    key = _key(name, labels)
    with _lock:
        _counters[key] = _counters.get(key, 0) + 1


def observe_ms(name: str, ms: float, /, **labels: str) -> None:
    """소요 시간(ms)을 누적한다."""
    key = _key(name, labels)
    with _lock:
        count, total, peak = _durations.get(key, (0, 0.0, 0.0))
        _durations[key] = (count + 1, total + ms, max(peak, ms))


def snapshot() -> dict[str, object]:
    """현재 값을 읽는다. 평균은 여기서 계산해 읽는 쪽이 나눗셈을 안 하게 한다."""
    with _lock:
        counters = dict(_counters)
        durations = {
            key: {
                "count": count,
                "total_ms": round(total, 1),
                "avg_ms": round(total / count, 1) if count else 0.0,
                "max_ms": round(peak, 1),
            }
            for key, (count, total, peak) in _durations.items()
        }
    return {"counters": counters, "durations": durations}


def reset() -> None:
    """테스트 격리용. 운영 경로에서는 부르지 않는다."""
    with _lock:
        _counters.clear()
        _durations.clear()
