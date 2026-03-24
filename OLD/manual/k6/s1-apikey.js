import { request, optionsForScenario } from "./common.js";

export const options = optionsForScenario("s1_apikey");

export default function () {
  request("apikey");
}
