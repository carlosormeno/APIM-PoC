import http from "k6/http";
import { check } from "k6";
import { Rate } from "k6/metrics";

const baseUrl = __ENV.BASE_URL || "https://apim.local";
const path = __ENV.PATH || "/";
const apiKey = __ENV.API_KEY || "";
const apiKeyHeader = (__ENV.API_KEY_HEADER || "x-api-key").toLowerCase();
const jwt = __ENV.JWT || "";
const jwtHeader = __ENV.JWT_HEADER || "Authorization";
const jwtPrefix = __ENV.JWT_PREFIX || "Bearer ";
const timeout = __ENV.TIMEOUT || "30s";

export const rateLimitHits = new Rate("rate_limit_hits");

function buildHeaders(authMode) {
  const headers = { "User-Agent": "poc-apim-k6" };

  if (authMode === "apikey" && apiKey) {
    headers[apiKeyHeader] = apiKey;
  }

  if (authMode === "jwt" && jwt) {
    headers[jwtHeader] = `${jwtPrefix}${jwt}`;
  }

  return headers;
}

export function request(authMode) {
  const url = `${baseUrl}${path}`;
  const headers = buildHeaders(authMode);
  const res = http.get(url, { headers, timeout });

  if (res.status === 429) {
    rateLimitHits.add(1);
  } else {
    rateLimitHits.add(0);
  }

  check(res, {
    "status is 2xx": (r) => r.status >= 200 && r.status < 300,
  });

  return res;
}

function defaultThresholds() {
  return {
    http_req_duration: ["p(95)<1500"],
    http_req_failed: ["rate<0.02"],
  };
}

function rateLimitThresholds() {
  return {
    http_req_duration: ["p(95)<2000"],
    http_req_failed: ["rate<0.60"],
    rate_limit_hits: ["rate>0"],
  };
}

export function optionsForScenario(name) {
  const rate = parseInt(__ENV.RPS || "50", 10);
  const preVUs = parseInt(__ENV.PRE_VUS || "50", 10);
  const maxVUs = parseInt(__ENV.MAX_VUS || "200", 10);
  const warmup = __ENV.WARMUP || "5m";
  const steady = __ENV.STEADY || "10m";
  const warmupRate = parseInt(__ENV.WARMUP_RPS || "1", 10);

  return {
    scenarios: {
      [name]: {
        executor: "ramping-arrival-rate",
        startRate: warmupRate,
        timeUnit: "1s",
        preAllocatedVUs: preVUs,
        maxVUs: maxVUs,
        stages: [
          { target: rate, duration: warmup },
          { target: rate, duration: steady },
        ],
      },
    },
    thresholds: name === "s3_rate_limit" ? rateLimitThresholds() : defaultThresholds(),
  };
}
