import { request, optionsForScenario } from "./common.js";

export const options = optionsForScenario("s3_rate_limit");

export default function () {
  request("apikey");
}
