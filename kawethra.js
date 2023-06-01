let routes = [];
let cache = {};
let params;
async function addRoute(route, path, title, func,) {
  routes.push({ route: route, path: path, title: title, func: func });
}

async function component() {
  let route = window.location.hash.substring(1);
  route = route.split("?param=");
  params = route;
  for (let i = 0; i < routes.length; i++) {
    if (route[0] == routes[i].route) {
      let page;
      if (!cache[routes[i].path]) {
        const response = await fetch(routes[i].path);
        page = await response.text();
        cache[routes[i].path] = page;
      } else {
        page = cache[routes[i].path];
      }
      page = await replaceDefultVariables(page);
      page = await replaceLoops(page);
      document.getElementById("main").innerHTML = page;
      document.title = routes[i].title;
      setTimeout(() => {
        routes[i].func();
        console.log(routes[i].func);
      }, 10);
      break;
    }
  }
}

async function replaceLoops(page) {
const regex = /%foreach\s+(\w+)\s+as\s+(\w+)%([\s\S]*?)%end%/g;
  let match;
  while ((match = regex.exec(page)) !== null) {
    const [, arrayName, itemName, loopContent] = match;
    const loopArray = eval(arrayName);
    let loopResult = '';
    for (const item of loopArray) {
      const replacedContent = loopContent.replace(new RegExp(`\\b${itemName}\\b`, 'g'), item);
      loopResult += replacedContent;
    }
    page = page.replace(match[0], loopResult);
  }
  return page;
}

async function replaceVariables(content, item, arrayName) {
  const regex = /%=(.*?)%/g;
  const matches = content.match(regex);
  let Array;
  if (arrayName) {
    const globalScope = (new Function('return this'))();
    if (globalScope.hasOwnProperty(arrayName)) {
      Array = globalScope[arrayName];
    }
  }
  let i = 0;
  if (arrayName) {
    if (matches) {
      for (const match of matches) {
        i++;
        const variableName = match.replace(/%=/g, "").trim();
        const variableValue = item;
        content = content.replace(match, Array[i]);
      }
    }
    if (matches) {
      for (const match of matches) {
        const variableName = match.replace(/%=/g, "").trim();
        const variableValue = getVariableValue(variableName);
        content = content.replace(match, variableValue);
      }
    }
  }
  return content;
}

function replaceDefultVariables(page){
  const regex = /%=(.*?)%/g;
  const matches = page.match(regex);
  if (matches) {
    for (const match of matches) {
      const variableName = match.replace(/%/g, "").trim();
      const variableValue = getVariableValue(variableName.split("=")[1]);
      page = page.replace(match, variableValue);
    }
  }
  return page;
}

function getVariableValue(variableName) {
  const globalScope = (new Function('return this'))();
  if (globalScope.hasOwnProperty(variableName)) {
    return globalScope[variableName];
  }
}

window.addEventListener('load', component);
window.addEventListener('hashchange', component);