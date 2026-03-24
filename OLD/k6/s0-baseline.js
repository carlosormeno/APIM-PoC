import { request, optionsForScenario } from "./common.js";

export const options = optionsForScenario("s0_baseline");

export default function () {
  request("none");
}
