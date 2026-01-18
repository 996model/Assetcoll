local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local dr = 240

-- FLAG GLOBAL
local loadingFinished = false

-- Cleanup
local existing = player.PlayerGui:FindFirstChild("AssetCollector")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AssetCollector"
gui.Parent = player:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false
gui.DisplayOrder = 1e9

----------------------------------------------------------------
-- TEST FRAME
----------------------------------------------------------------
local testFrame = Instance.new("Frame")
testFrame.Size = UDim2.fromScale(0.7, 0.6)
testFrame.Position = UDim2.fromScale(0.15, 0.2)
testFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
testFrame.Parent = gui

local instructionLabel = Instance.new("TextLabel")
instructionLabel.Size = UDim2.fromScale(1, 0.15)
instructionLabel.BackgroundTransparency = 1
instructionLabel.TextWrapped = true
instructionLabel.TextScaled = true
instructionLabel.TextColor3 = Color3.new(1,1,1)
instructionLabel.Text =
	"Try to copy the text you see on screen. If you can copy it, press OK. If you can't, press I CAN'T."
instructionLabel.Parent = testFrame

local testBox = Instance.new("TextBox")
testBox.Position = UDim2.fromScale(0, 0.15)
testBox.Size = UDim2.fromScale(1, 0.6)
testBox.MultiLine = true
testBox.TextWrapped = true
testBox.TextYAlignment = Enum.TextYAlignment.Top
testBox.ClearTextOnFocus = false
testBox.TextEditable = true
testBox.TextColor3 = Color3.new(1,1,1)
testBox.BackgroundColor3 = Color3.fromRGB(15,15,15)
testBox.Text = string.rep(
	"This is a very long stress test text intended to evaluate text selection and copy behavior. ",
	20
)
testBox.Parent = testFrame

local okButton = Instance.new("TextButton")
okButton.Size = UDim2.fromScale(0.45, 0.15)
okButton.Position = UDim2.fromScale(0.05, 0.8)
okButton.Text = "OK"
okButton.TextScaled = true
okButton.BackgroundColor3 = Color3.fromRGB(0,170,255)
okButton.TextColor3 = Color3.new(1,1,1)
okButton.Parent = testFrame

local cantButton = Instance.new("TextButton")
cantButton.Size = UDim2.fromScale(0.45, 0.15)
cantButton.Position = UDim2.fromScale(0.5, 0.8)
cantButton.Text = "I CAN'T"
cantButton.TextScaled = true
cantButton.BackgroundColor3 = Color3.fromRGB(120,120,120)
cantButton.TextColor3 = Color3.new(1,1,1)
cantButton.Parent = testFrame

----------------------------------------------------------------
-- ERROR MESSAGE
----------------------------------------------------------------
local function showCancelMessage()
	gui:ClearAllChildren()

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.fromScale(0.8, 0.2)
	msg.Position = UDim2.fromScale(0.1, 0.4)
	msg.BackgroundTransparency = 1
	msg.TextWrapped = true
	msg.TextScaled = true
	msg.TextColor3 = Color3.fromRGB(255, 80, 80)
	msg.Text = "Sorry, you cannot proceed if you are not able to copy."
	msg.Parent = gui
end

----------------------------------------------------------------
-- MAIN UI (LOADING)
----------------------------------------------------------------
local container = Instance.new("Frame")
container.Size = UDim2.fromScale(0.9, 0.15)
container.Position = UDim2.fromScale(0.05, 0.02)
container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
container.Visible = false
container.Parent = gui

local loadingHolder = Instance.new("Frame")
loadingHolder.Size = UDim2.fromScale(0.9, 0.35)
loadingHolder.Position = UDim2.fromScale(0.05, 0.2)
loadingHolder.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
loadingHolder.Parent = container

local loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.fromScale(0, 1)
loadingBar.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
loadingBar.Parent = loadingHolder

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255))
}
gradient.Parent = loadingBar

local instructionBottom = Instance.new("TextLabel")
instructionBottom.Size = UDim2.fromScale(1, 0.3)
instructionBottom.Position = UDim2.fromScale(0, 0.6)
instructionBottom.BackgroundTransparency = 1
instructionBottom.TextWrapped = true
instructionBottom.TextScaled = true
instructionBottom.TextColor3 = Color3.new(1,1,1)
instructionBottom.Text =
	"Instruction: Play the game normally, try to interact with menus, buttons and achieve objectives. Stop when the bar is fully loaded."
instructionBottom.Parent = container

local cantFinalButton

----------------------------------------------------------------
-- ASSET COLLECTION
----------------------------------------------------------------
local soundSet, imageButtonSet, imageLabelSet, decalSet = {}, {}, {}, {}
local globalIdSet = {} -- Set global para evitar IDs duplicados entre categorías
local startTime
local connection

local function extractId(assetString)
	return assetString:match("(%d+)")
end

-- Función para verificar si el asset debe ser filtrado
local function shouldFilter(assetString)
	-- Filtrar si contiene "AvatarHeadShot"
	if assetString:find("AvatarHeadShot") then
		return true
	end
	return false
end

-- Función para agregar asset solo si no está duplicado globalmente
local function addAssetIfUnique(set, assetString)
	if shouldFilter(assetString) then
		return false
	end

	local id = extractId(assetString)
	if id then
		-- Verificar si el ID ya existe globalmente
		if globalIdSet[id] then
			return false
		end
		-- Marcar como usado globalmente y agregar al set específico
		globalIdSet[id] = true
		set[assetString] = true
		return true
	end
	return false
end

local function buildIdNameList(set)
	local t = {}
	for v in pairs(set) do
		local id = extractId(v)
		if id then
			table.insert(t, id)
		end
	end
	table.sort(t)
	return table.concat(t, ", ")
end

local function resolveAssetName(assetString)
	local id = tonumber(assetString:match("rbxassetid://(%d+)"))
	if id then
		return assetString
	end
	return assetString 
end
local function getSortedKeys(set)
	local t = {}
	for v in pairs(set) do
		table.insert(t, v)
	end
	table.sort(t)
	return t
end
local function buildFormattedList(set)
	local out = {}
	for _, raw in ipairs(getSortedKeys(set)) do
		table.insert(out, resolveAssetName(raw))
	end
	return table.concat(out, ", ")
end

local function typewrite(textBox, fullText, onFinished)
	textBox.TextEditable = false
	textBox.Text = ""
	for i = 1, #fullText do
		textBox.Text = fullText:sub(1, i)
		task.wait(0.0001)
	end
	textBox.TextEditable = true
	if cantFinalButton and cantFinalButton.Parent then
		cantFinalButton.Visible = true
	end
	if onFinished then
		onFinished()
	end

	-- Conexión para restaurar texto si el cliente lo modifica
	local originalText = fullText
	local restoreThread = nil

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		if textBox.Text ~= originalText then
			-- Cancelar restauración anterior si existe
			if restoreThread then
				task.cancel(restoreThread)
			end
			-- Esperar 2 segundos y restaurar
			restoreThread = task.delay(2, function()
				if textBox.Parent then
					textBox.Text = originalText
				end
				restoreThread = nil
			end)
		end
	end)
end

local function enableTimedAutoResize(textObject, baseSize, minSize)
	baseSize = baseSize or 18
	minSize = minSize or 6
	textObject.TextSize = baseSize
	local stopResize = false

	task.spawn(function()
		while textObject.Parent and not stopResize do
			task.wait(1)
			if stopResize then break end
			textObject.TextSize = baseSize
			while not textObject.TextFits and textObject.TextSize > minSize do
				if stopResize then break end
				textObject.TextSize -= 1
				task.wait()
			end
		end
	end)

	return function()
		stopResize = true
	end
end

----------------------------------------------------------------
-- LOADING ANIMATION
----------------------------------------------------------------
local function startLoadingAnimation(textBox)
	local stopLoading = false
	local loadingStates = {"Loading.", "Loading..", "Loading..."}
	local index = 1

	task.spawn(function()
		while not stopLoading and textBox.Parent do
			textBox.Text = loadingStates[index]
			index = index % 3 + 1
			task.wait(0.4)
		end
	end)

	return function()
		stopLoading = true
	end
end

----------------------------------------------------------------
-- START COLLECTOR
----------------------------------------------------------------
local function startCollector()
	container.Visible = true
	testFrame:Destroy()
	startTime = os.clock()

	TweenService:Create(
		loadingBar,
		TweenInfo.new(dr, Enum.EasingStyle.Linear),
		{Size = UDim2.fromScale(1, 1)}
	):Play()

	connection = RunService.RenderStepped:Connect(function()
		for _, inst in ipairs(game:GetDescendants()) do
			if inst:IsA("Sound") and inst.SoundId ~= "" then
				addAssetIfUnique(soundSet, inst.SoundId)
			elseif inst:IsA("ImageButton") and inst.Image ~= "" then
				addAssetIfUnique(imageButtonSet, inst.Image)
			elseif inst:IsA("ImageLabel") and inst.Image ~= "" then
				addAssetIfUnique(imageLabelSet, inst.Image)
			elseif inst:IsA("Decal") and inst.Texture ~= "" then
				addAssetIfUnique(decalSet, inst.Texture)
			end
		end

		if os.clock() - startTime >= dr then
			connection:Disconnect()
			container:ClearAllChildren()
			container.Size = UDim2.fromScale(0.9, 0.85)

			------------------------------------------------
			-- HEADER
			------------------------------------------------
			local header = Instance.new("Frame")
			header.Size = UDim2.fromScale(1, 0.12)
			header.BackgroundTransparency = 1
			header.Parent = container

			local headerText = Instance.new("TextLabel")
			headerText.Size = UDim2.fromScale(0.85, 1)
			headerText.BackgroundTransparency = 1
			headerText.TextWrapped = true
			headerText.TextScaled = true
			headerText.TextXAlignment = Enum.TextXAlignment.Left
			headerText.TextColor3 = Color3.new(1,1,1)
			headerText.Text =
				"Wait until the text finishes writing so you can copy it. If the text is too long and you cannot copy it all, click here →"
			headerText.Parent = header

			cantFinalButton = Instance.new("TextButton")
			cantFinalButton.Size = UDim2.fromScale(0.15, 0.8)
			cantFinalButton.Position = UDim2.fromScale(0.85, 0.1)
			cantFinalButton.Text = "I CAN'T"
			cantFinalButton.TextScaled = true
			cantFinalButton.BackgroundColor3 = Color3.fromRGB(120,120,120)
			cantFinalButton.TextColor3 = Color3.new(1,1,1)
			cantFinalButton.Parent = header
			cantFinalButton.Visible = false

			------------------------------------------------
			-- TEXTBOX CON LOADING ANIMATION
			------------------------------------------------
			local box = Instance.new("TextBox")
			box.Position = UDim2.fromScale(0, 0.12)
			box.Size = UDim2.fromScale(1, 0.88)
			box.MultiLine = true
			box.TextWrapped = true
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.TextYAlignment = Enum.TextYAlignment.Top
			box.BackgroundColor3 = Color3.fromRGB(20,20,20)
			box.TextColor3 = Color3.fromRGB(85,255,0)
			box.Font = Enum.Font.Michroma
			box.TextSize = 18
			box.ClearTextOnFocus = false
			box.TextEditable = false
			box.Text = "Loading."
			box.Parent = container

			local stopResize = enableTimedAutoResize(box, 18, 6)

			-- Iniciar animación de loading
			local stopLoadingAnim = startLoadingAnimation(box)

			-- Procesar assets en segundo plano y luego escribir
			task.spawn(function()
				local finalText =
					"SOUNDS:\n" .. buildFormattedList(soundSet) ..
					"\n\nIMAGEBUTTONS:\n" .. buildFormattedList(imageButtonSet) ..
					"\n\nIMAGELABELS:\n" .. buildFormattedList(imageLabelSet) ..
					"\n\nDECALS:\n" .. buildFormattedList(decalSet)

				-- Detener animación de loading
				stopLoadingAnim()

				-- Comenzar typewrite
				typewrite(box, finalText, stopResize)
			end)

			------------------------------------------------
			-- BOTÓN I CAN'T (ALTERNATIVO)
			------------------------------------------------
			cantFinalButton.MouseButton1Click:Connect(function()
				box:Destroy()
				header:Destroy()

				local titles = {"SOUNDS","IMAGELABELS","IMAGEBUTTONS","DECALS"}
				local sets = {soundSet, imageLabelSet, imageButtonSet, decalSet}

				for i = 1, 4 do
					local col = Instance.new("Frame")
					col.Size = UDim2.fromScale(0.23, 1)
					col.Position = UDim2.fromScale((i-1)*0.25, 0)
					col.BackgroundTransparency = 1
					col.Parent = container

					local title = Instance.new("TextLabel")
					title.Size = UDim2.fromScale(1, 0.08)
					title.BackgroundTransparency = 1
					title.TextScaled = true
					title.TextColor3 = Color3.new(1,1,1)
					title.Text = titles[i]
					title.Parent = col

					local altBox = Instance.new("TextBox")
					altBox.Position = UDim2.fromScale(0, 0.08)
					altBox.Size = UDim2.fromScale(1, 0.92)
					altBox.MultiLine = true
					altBox.TextWrapped = true
					altBox.TextXAlignment = Enum.TextXAlignment.Left
					altBox.TextYAlignment = Enum.TextYAlignment.Top
					altBox.ClearTextOnFocus = false
					altBox.TextEditable = false
					altBox.Font = Enum.Font.Michroma
					altBox.TextSize = 16
					altBox.BackgroundColor3 = Color3.fromRGB(20,20,20)
					altBox.TextColor3 = Color3.fromRGB(85,255,0)
					altBox.Text = "Loading."
					altBox.Parent = col

					-- Iniciar animación de loading y procesar en segundo plano
					local stopAnim = startLoadingAnimation(altBox)
					local stopResizeAlt = enableTimedAutoResize(altBox, 16, 6)
					task.spawn(function()
						local data = buildIdNameList(sets[i])
						stopAnim()
						typewrite(altBox, data, stopResizeAlt)
					end)
				end
			end)
		end
	end)
end

----------------------------------------------------------------
-- BUTTONS
----------------------------------------------------------------
okButton.MouseButton1Click:Connect(startCollector)
cantButton.MouseButton1Click:Connect(showCancelMessage)

return function()
end
