state("REPO")
{
}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    vars.Helper.GameName = "R.E.P.O.";
    vars.Helper.UnityVersion = new Version(2022, 3);
    vars.Helper.AlertLoadless();

    settings.Add("debugLog", false, "Enable Debug Logging");

    settings.Add("tutorialSplits", true, "Split on completing Tutorial Stage");
    settings.Add("tut1", false, "Move", "tutorialSplits");
    settings.Add("tut2", false, "Jump", "tutorialSplits");
    settings.Add("tut3", false, "Crouch", "tutorialSplits");
    settings.Add("tut4", false, "Hide", "tutorialSplits");
    settings.Add("tut5", false, "Run", "tutorialSplits");
    settings.Add("tut6", false, "Tumble", "tutorialSplits");
    settings.Add("tut7", false, "Grab Objects", "tutorialSplits");
    settings.Add("tut8", false, "Scroll Objects", "tutorialSplits");
    settings.Add("tut9", false, "Rotate Objects", "tutorialSplits");
    settings.Add("tut10", false, "Toggle Items", "tutorialSplits");
    settings.Add("tut11", false, "Store Items", "tutorialSplits");
    settings.Add("tut12", false, "View Map", "tutorialSplits");
    settings.Add("tut13", false, "Grab Cart", "tutorialSplits");
    settings.Add("tut14", false, "Fill Cart", "tutorialSplits");
    settings.Add("tut15", false, "Fill Extraction", "tutorialSplits");

    settings.Add("taxSplit", true, "Split on reaching currency amount");
    settings.Add("100", false, "100K", "taxSplit");
    settings.Add("250", false, "250K", "taxSplit");
    settings.Add("500", false, "500K", "taxSplit");
    settings.Add("1000", false, "1M", "taxSplit");
    settings.Add("2000", false, "2M", "taxSplit");

    settings.Add("levelSplit", true, "Split on completing a Level");
    settings.Add("everyNLevels", true, "Split every n levels (Every 1 Level is on by default)", "levelSplit");
    for (var i = 1; i <= 10; i++)
        settings.Add("nLevel_" + i, i == 1, i + " Levels", "everyNLevels");

    settings.Add("specificLevels", true, "Split after specific levels", "levelSplit");
    for (var i = 1; i <= 200; i++)
        settings.Add("specLevel_" + i, false, "Level " + i, "specificLevels");
}

init
{
    if (settings["debugLog"])
        print("INIT fired");

    vars.previousLevel = "Main Menu";
    vars.currencySplits = new List<int>() { 100, 250, 500, 1000, 2000 };
    vars.daysCompleted = 0;
    vars.hookReady = false;
    vars.tryLoadAttempts = 0;
    vars.pendingStart = false;
    vars.attachTick = Environment.TickCount;
    vars.hookDelayMs = 3000;

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        if (Environment.TickCount - vars.attachTick < vars.hookDelayMs)
            return false;

        vars.tryLoadAttempts++;
        if (settings["debugLog"])
            print("TryLoad attempt #" + vars.tryLoadAttempts);

        try
        {
            var state = mono.Make<int>("GameDirector", "instance", "currentState");
            if (settings["debugLog"])
                print("state ok");

            var levelsCompleted = mono.Make<int>("RunManager", "instance", "levelsCompleted");
            if (settings["debugLog"])
                print("levelsCompleted ok");

            var levelName = mono.MakeString("RunManager", "instance", "levelCurrent", "NarrativeName");
            if (settings["debugLog"])
                print("levelName ok");

            var tutorialStage = mono.Make<int>("TutorialDirector", "instance", "currentPage");
            if (settings["debugLog"])
                print("tutorialStage ok");

            var currency = mono.Make<int>("CurrencyUI", "instance", "currentHaulValue");
            if (settings["debugLog"])
                print("currency ok");

            vars.Helper["state"] = state;
            vars.Helper["levelsCompleted"] = levelsCompleted;
            vars.Helper["levelName"] = levelName;
            vars.Helper["tutorialStage"] = tutorialStage;
            vars.Helper["currency"] = currency;

            vars.hookReady = true;
            if (settings["debugLog"])
                print("TryLoad success");

            return true;
        }
        catch (Exception e)
        {
            vars.hookReady = false;
            if (settings["debugLog"])
                print("TryLoad failed: " + e.Message);

            return false;
        }
    });
}

exit
{
    if (settings["debugLog"])
        print("EXIT fired");

    vars.hookReady = false;
    vars.pendingStart = false;
    vars.previousLevel = "Main Menu";
    vars.currencySplits = new List<int>() { 100, 250, 500, 1000, 2000 };
    vars.daysCompleted = 0;
}

onStart
{
    vars.daysCompleted = 0;
    vars.pendingStart = false;
    vars.currencySplits = new List<int>() { 100, 250, 500, 1000, 2000 };
}

update
{
    if (!(vars.hookReady ?? false))
        return false;

    if (current.levelName != old.levelName)
    {
        if (current.levelName == "Main Menu" || current.levelName == "Lobby Menu")
        {
            vars.pendingStart = false;

            if (settings["debugLog"])
                print("pendingStart cleared: entered menu");
        }
        else if ((old.levelName == "Main Menu" || old.levelName == "Lobby Menu")
            && current.levelName != "Main Menu"
            && current.levelName != "Lobby Menu")
        {
            vars.pendingStart = true;

            if (settings["debugLog"])
                print("pendingStart set: " + old.levelName + " -> " + current.levelName);
        }

        vars.previousLevel = old.levelName;
    }

    return true;
}

start
{
    if (!(vars.hookReady ?? false))
        return false;

    if (vars.pendingStart
        && old.state != 2
        && current.state == 2
        && current.levelName != "Main Menu"
        && current.levelName != "Lobby Menu")
    {
        vars.pendingStart = false;

        if (settings["debugLog"])
            print("Start triggered");

        return true;
    }

    return false;
}

split
{
    if (!(vars.hookReady ?? false))
        return false;

    // Tutorial splits
    if (settings["tutorialSplits"])
    {
        if (current.levelName != old.levelName)
        {
            // If going to main menu, and coming from completed tutorial
            if (current.levelName == "Main Menu")
            {
                if (old.levelName == "Tutorial" && current.tutorialStage == 16)
                    return true;

                return false;
            }
        }

        if (old.tutorialStage != current.tutorialStage)
        {
            // Split on user-selected tutorial stages
            if (current.tutorialStage >= 1 && current.tutorialStage <= 15)
            {
                if (settings["tut" + current.tutorialStage])
                    return true;
            }
        }
    }

    // Level splits
    if (settings["levelSplit"])
    {
        if (current.levelName != old.levelName)
        {
            if (current.levelName == "Main Menu")
                return false;

            if (old.levelName != "Service Station"
                && old.levelName != "Truck"
                && current.levelName != "Disposal Arena")
            {
                if (settings["specificLevels"] && settings["specLevel_" + current.levelsCompleted])
                    return true;

                if (settings["everyNLevels"])
                {
                    for (int i = 1; i <= 10; i++)
                    {
                        if (settings["nLevel_" + i] && current.levelsCompleted % i == 0)
                            return true;
                    }
                }
            }
        }
    }

    // Tax splits
    if (settings["taxSplit"])
    {
        if (old.currency != current.currency)
        {
            if (current.currency >= 100 && settings["100"] && vars.currencySplits.Contains(100))
            {
                vars.currencySplits.Remove(100);
                return true;
            }
            if (current.currency >= 250 && settings["250"] && vars.currencySplits.Contains(250))
            {
                vars.currencySplits.Remove(250);
                return true;
            }
            if (current.currency >= 500 && settings["500"] && vars.currencySplits.Contains(500))
            {
                vars.currencySplits.Remove(500);
                return true;
            }
            if (current.currency >= 1000 && settings["1000"] && vars.currencySplits.Contains(1000))
            {
                vars.currencySplits.Remove(1000);
                return true;
            }
            if (current.currency >= 2000 && settings["2000"] && vars.currencySplits.Contains(2000))
            {
                vars.currencySplits.Remove(2000);
                return true;
            }
        }
    }

    return false;
}

isLoading
{
    if (!(vars.hookReady ?? false))
        return false;

    // State 2 is "Main" state, applicable to Main Menu and actual Gameplay
    // State 6 is "Death" State
    return (current.state != 2 && current.state != 6);
}

reset
{
    if (!(vars.hookReady ?? false))
        return false;

    if (current.levelName != old.levelName)
    {
        if (current.levelName == "Main Menu" || current.levelName == "Disposal Arena")
        {
            vars.pendingStart = false;

            if (old.levelName == "Tutorial" && current.tutorialStage == 16)
                return false; // Finished Tutorial, don't reset

            return true;
        }
    }

    return false;
}
