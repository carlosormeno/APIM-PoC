import { request, optionsForScenario } from "./common.js";

export const options = optionsForScenario("s2_jwt");

export default function () {
  request("jwt");
}
