% THIS SOFTWARE WAS DEVELOPED AT THE US FOREST SERVICE, SOUTHERN RESEARCH STATION (SRS), COWEETA HYDROLOGIC LABORATORY BY EMPLOYEES OF THE FEDERAL GOVERNMENT IN THE COURSE OF THEIR OFFICIAL DUTIES. 
% PURSUANT TO TITLE 17 SECTION 105 OF THE UNITED STATES CODE, THIS SOFTWARE IS NOT SUBJECT TO COPYRIGHT PROTECTION AND IS IN THE PUBLIC DOMAIN. 
% SRS COWEETA HYDROLOGIC LABORATORY ASSUMES NO RESPONSIBILITY WHATSOEVER FOR ITS USE BY OTHER PARTIES,  AND MAKES NO GUARANTEES, EXPRESSED OR IMPLIED, ABOUT ITS QUALITY, RELIABILITY, OR ANY OTHER CHARACTERISTIC.  
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
% 
% This file is part of Baseliner.
% 
% Baseliner is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.
% Baseliner is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License along with Baseliner. If not, see <http://www.gnu.org/licenses/>.

function config = projectDialog(origConfig)
    % Presents a rudimentary dialog to set project configuration
    % parameters. This uses the fairly limited inputdlg() facility - a
    % constraint that forces us to select filenames beforehand with a
    % separate call to getfile().
    %
    % The user's input is checked when they press "okay". If there's an issue
    % then an error dialog is displayed and the user may then correct the problem.
    %
    % If successful the updated config is returned; if the user cancels then 0
    % is returned.


    function fail(format, varargin)
        % Convenience function that wrappers the exception throwing code.
        % This is called if any user entry is not valid.  It is caught in the
        % projectDialog() body.
        throw(MException('pd:err', format, varargin{:}));
    end


    function val = getFloat(index, minVal, maxVal)
        % Attempts to read a float from entry field number 'index'.  The value
        % must fall in the specified range.
        val = str2double(values{index});
        if isnan(val)
            fail('%s should be a single float', prompt{index});
        end
        if val < minVal
            fail('%s should be greater than %f', prompt{index}, minVal);
        end
        if val > maxVal
            fail('%s should be less than %f', prompt{index}, maxVal);
        end
    end


    function val = getInt(index, minVal, maxVal)
        % Attempts to read an int from entry field number 'index'.  The value
        % must fall in the specified range.
        val = getFloat(index, minVal, maxVal);
        if round(val) ~= val
            fail('%s should be an integer', prompt{index});
        end
    end


    function val = getFilename(index)
        % Check that field index holds a valid filename.  If so return it.
        val = values{index};
        if exist(values{index}, 'file') ~= 2
            fail('%s is not a valid file', val);
        end
    end


    dlgTitle = 'Project Configuration';
    prompt = { ...
        'Source data filename:', ...
        'Project name:', ...
        'Project description:', ...
        'Time step increments (minutes):', ...
        'Minimum valid sapflow value:', ...
        'Maximum valid sapflow value:', ...
        'Maximum change per interval:', ...
        'Delete data segments shorter than X points:', ...
        'PAR threshold: values below this are considered nighttime', ...
        'VPD threshold: values below this are considered zero', ...
        'VPD time: length in hours of time segment of low-VPD conditions', ...
    };

    % set default values
    values = { ...
        origConfig.sourceFilename, ...
        origConfig.projectName, ...
        origConfig.projectDesc, ...
        num2str(origConfig.Timestep), ...
        num2str(origConfig.minRawValue), ...
        num2str(origConfig.maxRawValue), ...
        num2str(origConfig.maxRawStep), ...
        num2str(origConfig.minRunLength), ...
        num2str(origConfig.parThresh), ...
        num2str(origConfig.vpdThresh), ...
        num2str(origConfig.vpdTime), ...
    };
    % Set all fields to 100 characters wide.
    fieldSize = ones(length(values),1) * [1,100];

    % We return from inside this loop.
    while true
        values = inputdlg(prompt, dlgTitle, fieldSize, values);
        if isempty(values)
            config = 0;  % Communicate that the user has aborted entry.
            return
        end
        try
            config.sourceFilename = getFilename(1);
            config.projectName = values{2};
            config.projectDesc = values{3};
            config.Timestep = getFloat(4, 0, 100);
            config.minRawValue = getFloat(5, 0, 100);
            config.maxRawValue = getFloat(6, config.minRawValue, 100);
            config.maxRawStep = getFloat(7, 0, 100);
            config.minRunLength = getInt(8, 0, 100);
            config.parThresh = getFloat(9, 0, 100);
            config.vpdThresh = getFloat(10, 0, 100);
            config.vpdTime = getFloat(11, 0, 100);

            % If we've got this far then everything is okay and we can return
            % with a valid config.
            return
        catch err
            % There's been an exception; if it's one of ours then the user has
            % entered bad data.  Alert them to this and repeat.
            if strcmp(err.identifier, 'pd:err')
                uiwait(errordlg(err.message, 'Bad Value', 'modal'));
                continue;  % Repeat the process using the last set of values.
            else
                % It's not our bad entry exception - best let it be handled up
                % the food chain.
                rethrow(err)
            end
        end
    end


end
