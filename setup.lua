-- Defining url from repository
local quarry_url = "https://raw.githubusercontent.com/JacobIsTaken/turtle-code/main/quarry.lua"
local inv_url = "https://raw.githubusercontent.com/JacobIsTaken/turtle-code/main/inv.lua"
local t_url = "https://raw.githubusercontent.com/JacobIsTaken/turtle-code/main/t.lua"

-- Define the local path where the file should be saved
local quarry_path = "quarry"
local inv_path = "inv"
local t_path = "t"

-- Function to download a file from a URL
local function downloadFile(url, path)
    print("Downloading file from: " .. url)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        local file = fs.open(path, "w")
        file.write(content)
        file.close()
        response.close()
        print("Downloaded file saved as: " .. path)
    else
        print("Failed to download file from: " .. url)
    end
end

-- Download the file
downloadFile(quarry_url, quarry_path)
downloadFile(inv_url, inv_path)
downloadFile(t_url, t_path)