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

classdef SapflowProcessor < handle
    % Implements the core sapflow analysis algorithms.
    %
    % Handles baseline estimation and manual adjustment, and sapflow data
    % correction.  Each instance handles a single sensor.

    properties (SetAccess = private, GetAccess = public)
        % The following are loaded from a file and are all the same 1 x N
        % size.

        doy % Day of Year
        tod % Time of Day
        vpd % Vapour Pressure Deficit
        par % Photosynthetically Active Radiation
        ss  % sapflow measurement sequence

        ssOrig

        ssL % length of sapflow data (N)

        % These are generated automatically from the sapflow values:
        % The are 1 x N vectors of indexes

        zvbl % points where nighttime VPD is zero for at least threshold duration
        spbl % zvbl values where standard deviation is less than threshold limit
        lzvbl % final zvbl value each night

        bli % Baseline initial, picks nightly max; a 1 x N
        bla % Baseline adjusted (manually); a 1 x N

        % these are 1xN vectors of the same length as the ss vectors
        k_line
        ka_line
        nvpd

        % Store our configuration in this structure.
        config
    end

    properties (Access = private)
        cmdStack % Last on, first off stack of previously entered commands - allows undoing.
    end

    properties (SetAccess = public, GetAccess = public)

        % These allow configuration of the tool...
%        Timestep = 15;

        % External function to be called when the baseline data is changed;
        % this will usually be to update a graph to reflect the change.
        baselineCallback

        % External function to call when sapflow data is changed.
        sapflowCallback

        % Called after each command is executed or undo requested.  It is passed a string
        % describing the last operation that can be undone.  Alternately if
        % there are no more commands to undo, 0 passed
        undoCallback
    end

    methods


        function o = SapflowProcessor(doy, tod, vpd, par, ss, config)
            % Constructor just stores the passed values.
            o.doy = doy;
            o.tod = tod;
            o.vpd = vpd;
            o.par = par;
            o.ssOrig = oneByN(ss);
            o.ss = oneByN(ss);
            o.ssL = length(o.ss);
            o.spbl = [1,o.ssL];
            o.zvbl = [1,o.ssL];
            o.lzvbl = [1,o.ssL];
            o.bli = BL_nightly(o.ss,o.doy,o.tod);

%            o.bla = [1,o.ssL];
            o.bla = o.bli; % uses initial baseline as starting point for adjustments

            o.cmdStack = Stack(); % Used for undoing commands.

            o.config = config;
        end


        function setup(o)
            % Called each time this SFP gets focus
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
            else
                nextCmd = o.cmdStack.peek();
                o.undoCallback(nextCmd{1});
            end

        end


        function cleanRawData(o)
            % Cleans the raw sapflow data according to the config settings.
            % Note that this doesn't get logged in the undo stack.  It would
            % only be called for new projects, and the project would be saved
            % before any further modifications.
            % So, either this or setModifications() is called directly after
            % constructing the object.
            o.ss = cleanRawFluxData(o.ss, o.config);
        end


        function isChange = changesMade(o)
            % Called before potentially discarding work by closed
            % application or project.
            isChange = not(o.cmdStack.isEmpty());
        end


        function s = getModifications(o)
            % Return a structure detailing all the changes made to the data in
            % this object.  This structure is saved into the project file.
            % Resets the undo stack.  %TEMP!!! should probably do this separately after the project has saved successfully.
            s.bla = o.bla;
            s.spbl = o.spbl;
            s.zvbl = o.zvbl;
            s.lzvbl = o.lzvbl;
            unchanged = (o.ss == o.ssOrig) | (isnan(o.ss) & isnan(o.ssOrig));

            [ts, te] = getRanges(~unchanged);
            len = length(ts);
            s.sapflow.cut = {};
            s.sapflow.new = {};
            for i = 1:len
                data = o.ss(ts(i):te(i));
                if all(isnan(data))
                    s.sapflow.cut{end+1} = struct('start', ts(i), 'end', te(i));
                else
                    s.sapflow.new{end+1} = struct('start', ts(i), 'end', te(i), 'data', data);
                end
            end

            o.emptyUndoStack();

        end


        function setModifications(o, s)
            % Reads the set of modifications made to the raw data and applies
            % them.  These will be read from the project file.  Resets the undo
            % stack.
            o.bla = s.bla;
            o.spbl = s.spbl;
            o.zvbl = s.zvbl;
            o.lzvbl = s.lzvbl;
            for seg = s.sapflow.cut
                segv = seg{1};
                o.ss(segv.start:segv.end) = NaN;
            end
            for seg = s.sapflow.new
                segv = seg{1};
                o.ss(segv.start:segv.end) = segv.data;
            end

            o.emptyUndoStack();

        end


        function undo(o)
            % Each editing command can be undone one at a time.

            % Each entry is a 1 x N cell array containing:
            % - command description text (ignored by this method)
            % - handle to function that performs the actions to undo
            % - additional elements are passed as an argument to the
            % function
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
                % nothing left to undo
                return;
            end

            cmd = o.cmdStack.pop();
            func = cmd{2};
            args = cmd{3};
            func(args);
            if o.cmdStack.isEmpty()
                o.undoCallback(0)
            else
                nextCmd = o.cmdStack.peek();
                o.undoCallback(nextCmd{1});
            end
        end


        function addBaselineAnchors(o, t)
            % Anchor the baseline to sapflow at the specified times t.
            % t is a 1xN vector.
            % This command can be undone.
            o.pushCommand('add baseline anchors', @o.undoBaselineChange, o.bla);
            o.bla = unique([o.bla, t]);
            o.compute();
            o.baselineCallback();
        end


        function delBaselineAnchors(o, i)
            % Delete the baseline anchor points with the index values i
            % i is a 1xN vector.
            % This command can be undone.
            o.pushCommand('delete baseline anchors', @o.undoBaselineChange, o.bla);
            o.bla(i) = [];
            o.compute();
            o.baselineCallback();
        end


        function delSapflow(o, regions)
            % Delete the sapflow values in the specified regions.
            % regions is a 1xN cell array, where each cell is a 1x2 array
            % of the form [tStart, tEnd].
            %
            % Sapflow data are deleted by setting the values to NaN.
            % Any baseline values in these ranges will also be deleted.
            %
            % This command can be undone.
            o.modifySapflow(regions, @o.delSapflowSegment, 'delete sapflow data')
        end


        function interpolateSapflow(o, regions)
            % The same as delSapflow() except that the sapflow changes
            % linearly over each range from the value at start to the value
            % at the end.
            % regions is a 1xN cell array, where each cell is a 1x2 array
            % of the form [tStart, tEnd].
            %
            % Any baseline values in these ranges will be deleted.
            %
            % This command can be undone.
            o.modifySapflow(regions, @o.interpSapflowSegment, 'interpolate sapflow data')
        end


        function auto(o)
            % Apply an algorithm to the sapflow data to identify some
            % candidate baseline anchor points.
            %
            % Populates the spbl, zvbl, lzvbl and bla vectors.
            %

            o.pushCommand('autoassign BL anchors', @o.undoSapflowChange, {{}, o.bla, o.spbl, o.zvbl, o.lzvbl});

            nDOY = o.doy;
            nDOY(o.tod < 1000) = nDOY(o.tod < 1000) - 1;

            [mySpbl, ~, myZvbl, myLzvbl] = BL_auto( ...
                o.ss', o.doy, nDOY, o.config.Timestep, o.par, o.config.parThresh, ...
                o.vpd, o.config.vpdThresh, o.config.vpdTime ...
            );

            o.spbl = oneByN(mySpbl);  %TEMP!!! there must be a nicer way of ensuring 1xN shape.
            o.zvbl = oneByN(myZvbl);
            o.lzvbl = oneByN(myLzvbl);

            iValidSamples = find(isfinite(o.ss));
            iFirstValid = min(iValidSamples);
            iLastValid = max(iValidSamples);
            if iFirstValid == o.lzvbl(1)
                iFirstValid = [];
            end
            if iLastValid == o.lzvbl(end)
                iLastValid = [];
            end

            o.bla = [iFirstValid, o.lzvbl, iLastValid];

            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end

        function autoNightly(o)
            % Apply an algorithm to the sapflow data to identify some
            % candidate baseline anchor points.

            % pop-up window to confirm that all baseline points will be changed
            %  Create and then hide the GUI as it is being constructed.
            f = figure('Visible','off','Position',[1,1,350,150],...
               'NumberTitle', 'off', 'MenuBar', 'none');

            htext = uicontrol('Style','text','String','All current dTmax points will be changed. Continue?',...
                  'Position',[25,80,250,50]);

            yesnight = uicontrol('Style','pushbutton','String',...
                  'Yes',...
                  'Position',[50,30,100,30],...
                  'Callback',@yesnight_Callback);
            nonight = uicontrol('Style','pushbutton','String',...
                  'No',...
                  'Position',[200,30,100,30],...
                  'Callback',@nonight_Callback);

            f.Name = 'Warning';
            % Move the GUI to the center of the screen.
            movegui(f,'center')
            % Make the GUI visible.
            f.Visible = 'on';

           %  Callbacks for simple_gui. These callbacks automatically
           %  have access to component handles and initialized data
           %  because they are nested at a lower level.

           %  Pop-up menu callback. Read the pop-up menu Value property
           %  to determine which item is currently displayed and make it
           %  the current data.
          function yesnight_Callback(source,eventdata)

            o.bla = BL_nightly(o.ss,o.doy,o.tod);

            o.compute();
            o.sapflowCallback();
            o.baselineCallback();

            pause(.5)
            close
            return;
          end
          function nonight_Callback(source,eventdata)

            pause(.5)
            close
            return;
          end


        end

%  Moved into stand-alone function
%         function [bl_night]=BL_nightly(o)
%             % establishes initial baseline based on maximum dT value each
%             % night (defined by time before 7:00 AM)
%             bl_night=[];
%             for d=min(o.doy):max(o.doy)
%                 DI=find(o.doy==d & o.tod<700 & o.ss'>0);
%                 if length(DI)>0
%                     [mDI,iDI]=max(o.ss(DI));
%                     if length(iDI)>=1
%                         bl_night=[bl_night;DI(iDI(1))];
%                     end
%                 end
%             end
%             bl_night=[1;bl_night;length(o.ssL)];
%             bl_night=unique(bl_night)';
%         end

        function compute(o)
            % Based on the sapflow, bla and VPD data, calculate the K, KA
            % and NVPD values.
            %
            if sum(o.ss(o.bli)>0)>=2
                blv = interp1(o.bli, o.ss(o.bli), (1:o.ssL));
                o.k_line = blv ./ o.ss - 1;
                o.k_line(o.k_line < 0) = 0;
            else
                blv=nan*o.zvbl;
                o.k_line = nan*o.ss;
            end

            % If at least two bla points are positive ...
            if sum(o.ss(o.bla)>0)>=2
                blv = interp1(o.bla, o.ss(o.bla), (1:o.ssL));
                o.ka_line = blv ./ o.ss - 1;
                o.ka_line(o.ka_line < 0) = 0;
                o.nvpd = o.vpd ./ max(o.vpd) .* max(o.ka_line);
            else
                o.ka_line = nan * o.ss;
                o.nvpd = o.vpd ./ max(o.vpd);
            end
        end


    end

    methods (Access = private)


        function undoBaselineChange(o, args)
            % Restore the baseline anchor values which were saved prior to
            % the previous command.
            o.bla = args;
            o.compute();
            o.baselineCallback();
        end


        function undoSapflowChange(o, args)
            % Restores the sapflow data ranges changed by the previous
            % command.  Restore the various candidate and manually defined
            % baseline anchor points.
            %
            % Blanket overright of baseline values, restoration of ss is
            % done one segment at a time
            [ssCutSeg, o.bla, o.spbl, o.zvbl, o.lzvbl] = args{1:end};
            for seg = ssCutSeg
                [ts, te, orig] = seg{1}{:};
                o.ss(ts:te) = orig;
            end

            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end


        function delSapflowSegment(o, ts, te)
            % Callback for modifySapflow().  All sapflow data in the ts to
            % te range are discarded.
            o.ss(ts:te) = NaN;
        end


        function interpSapflowSegment(o, ts, te)
            % Callback for modifySapflow().  A little more involved than
            % delSapflowSegment().  If either end of the range is NaN then
            % the whole range is set accordingly.  Otherwise we join the
            % start with the end with a straight line.
            if isnan(o.ss(ts)) || isnan(o.ss(te))
                return
            end
            o.ss(ts:te) = interp1([ts, te], o.ss([ts,te]), ts:te);
        end


        function modifySapflow(o, regions, segmentCallback, message)
            % Does the heavy lifting for interpolateSapflow() and
            % delSapflow().  For each region, identifies enclosed baseline
            % anchor points and marks them for deletion.  Also calls the
            % appropriate callback to modify the sapflow data.
            %
            % The baseline vectors are small enough to store complete.
            % Storing the complete sapflow vectors would chew up lots of
            % memory, so we just store the segments changes, along with
            % some location information.
            blaCutI = [];
            spblCutI = [];
            zvblCutI = [];
            lzvblCutI = [];
            ssCutSegs = {};

            [rows,~] = size(regions);
            for row = 1:rows
                ts = regions(row,1);
                te = regions(row,2);
                i = find(ts <= o.bla & te >= o.bla);
                blaCutI = [blaCutI, i]; %#ok<AGROW>

                i = find(ts <= o.spbl & te >= o.spbl);
                spblCutI = [spblCutI, i]; %#ok<AGROW>

                i = find(ts <= o.zvbl & te >= o.zvbl);
                zvblCutI = [zvblCutI, i]; %#ok<AGROW>

                i = find(ts <= o.lzvbl & te >= o.lzvbl);
                lzvblCutI = [lzvblCutI, i]; %#ok<AGROW>

                ssCutSegs{end+1} = {ts, te, o.ss(ts:te)}; %#ok<AGROW>

                segmentCallback(ts, te)
            end
            o.pushCommand(message, @o.undoSapflowChange, {ssCutSegs, o.bla, o.spbl, o.zvbl, o.lzvbl});
            o.bla(blaCutI) = [];
            o.spbl(spblCutI) = [];
            o.zvbl(zvblCutI) = [];
            o.lzvbl(lzvblCutI) = [];
            o.compute();
            o.sapflowCallback();
            o.baselineCallback();
        end


        function pushCommand(o, description, callback, params)
            % With each command executed we record what's done so it can be
            % undeleted if necessary.  A callback is invoked which might be
            % used to update the text in the GUI's undo button for example.
            %
            % Parameters:
            % - description: text detailing the operation (used for the
            %   callback to the user interface code.
            % - callback: the method to call to undo the action
            % - params: a 1xN cell array with the parameters needed by the
            %   undo callback.
            o.cmdStack.push({description, callback, params})
            if isa(o.undoCallback, 'function_handle')
                o.undoCallback(description);
            end
        end


        function emptyUndoStack(o)
            % Wipe the undo history.  Done when we we load or save changes.
            o.cmdStack = Stack(); % start a new stack
            o.undoCallback(0);  % report up that the stack is empty.
        end


    end

end
