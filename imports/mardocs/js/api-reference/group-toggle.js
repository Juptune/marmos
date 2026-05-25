function getGroupComponents(mainGroupElement) {
    return {
        id: mainGroupElement.dataset.id,
        category: mainGroupElement.dataset.category,
        depth: mainGroupElement.dataset.depth,
        mainElement: mainGroupElement,
        chevronElement: mainGroupElement.querySelector('[data-type="chevron"]'),
        childrenElement: mainGroupElement.querySelector('[data-type="children"]'),
    };
}

function getFullId(groupComponents) {
    let idPath = [groupComponents.id];
    let parent = groupComponents.mainElement.parentElement;
    while(parent) {
        const parentComponenets = getGroupComponents(parent);
        if(parentComponenets.id)
            idPath.push(parentComponenets.id);
        parent = parent.parentElement;
    }

    return idPath.reverse().join(".");
}

function rememberState(groupComponents) {
    return sessionStorage.getItem(getFullId(groupComponents));
}

function saveState(groupComponents) {
    const state = groupComponents.mainElement.dataset.state;
    const id = getFullId(groupComponents);
    sessionStorage.setItem(id, state);
}

function openGroup(groupComponents) {
    groupComponents.chevronElement.innerText = "v";
    groupComponents.childrenElement.style.display = "flex";
    groupComponents.mainElement.dataset.state = "open";
    saveState(groupComponents);
}

function closeGroup(groupComponents) {
    groupComponents.chevronElement.innerText = "^";
    groupComponents.childrenElement.style.display = "none";
    groupComponents.mainElement.dataset.state = "closed";
    saveState(groupComponents);
}

function toggleGroup(event) {
    event.stopPropagation();

    let parent = event.target;
    while(parent && parent.dataset.type !== "group") 
        parent = parent.parentElement

    if(!parent)
        return;

    const components = getGroupComponents(parent);
    if(components.mainElement.dataset.state === "open")
        closeGroup(components);
    else
        openGroup(components);
}

// Get all groups, and remember whether they were closed or open
const allGroups = document.querySelectorAll('[data-type="group"]');

for(const group of allGroups) {
    const components = getGroupComponents(group);
    const stateOrNull = rememberState(components);

    group.addEventListener('click', toggleGroup);

    // If this group is part of our nav node path, then open it
    if(components.chevronElement.classList.contains("font-bold")) {
        openGroup(components);
        continue;
    }

    if(!stateOrNull) {
        // Open all module groups that are 1 nesting level deep, but keep everything else closed.
        if(components.category === "m" && components.depth === 1) // module
            openGroup(components);
        else
            closeGroup(components);
    }
    else {
        if(stateOrNull === "open") 
            openGroup(components);
        else
            closeGroup(components);
    }
}

// Add a dummy click handler onto leaf items, so it stops the UI from flickering a bit
for(const leaf of document.querySelectorAll('[data-type="leaf"]')) {
    leaf.addEventListener("click", (e) => { e.stopPropagation(); });
}