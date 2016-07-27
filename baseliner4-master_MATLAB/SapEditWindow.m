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

classdef SapEditWindow < LineEditWindow
    % The sapflow data editing application.
    %
    % Allows operators to view and edit sapflow data and to specify a baseline
    % representing zero sapflow.
    % Revisions 3/23/2016 [ACO]:
    %   adds more labels; cosmetic only

    properties
        lines % Structure containing handles to each of the lines representing the data

        % structure to hold selected datapoints
        selection  %TEMP!!! rethink logic
        selectBox
        % selected

        sfp  % The SapflowProcessor object for the current sensor data.
        allSfp
        sfpI

        projectFilename

        projectConfig  % configuration common to all sensors

    end

    methods (Access = public)

         function o = SapEditWindow()
            % Constructor sets up window
            %
            % It added sapflow specific items to the generic LineEditWindow object.

            o@LineEditWindow(); % Create generic window.

            mf = uimenu(o.figureHnd, 'Label', 'File');
            me = uimenu(o.figureHnd, 'Label', 'Edit');
            mh = uimenu(o.figureHnd, 'Label', 'Help');

            uimenu(mf, 'Label', 'Open Project', 'Accelerator', 'O', 'Callback', @o.openProject);
            uimenu(mf, 'Label', 'New Project', 'Accelerator', 'N', 'Callback', @o.newProject);
            uimenu(mf, 'Label', 'Save Project', 'Accelerator', 'S', 'Callback', @o.saveProject);
            uimenu(mf, 'Label', 'Save As', 'Callback', @o.saveAs);
            uimenu(mf, 'Label', 'Export current K estimates', 'Callback', @o.export);
            uimenu(mf, 'Label', 'Export nightly dTmax K estimates', 'Callback', @o.export_nightly);
            uimenu(mf, 'Label', 'Export K error estimates', 'Callback', @o.export_kerror);
            uimenu(mf, 'Label', 'Exit', 'Accelerator', 'X', 'Callback', @o.checkExit);

            uimenu(mh, 'Label', 'About', 'Callback', @o.helpAbout);

            o.setWindowTitle('Baseliner 4')
            o.figureHnd.CloseRequestFcn = @o.checkExit;

            % Add in controls
            o.addCommandDesc('pantext0', 0, 'dT editor window display',      1, 16);
            o.addCommand('panLeft',  0, '< pan',         'leftarrow',  'pan focus area left',       2, 15, @(~,~)o.zoomer.pan(-0.8));
            o.addCommand('panRight', 0, 'pan >',         'rightarrow', 'pan focus area right',      3, 15, @(~,~)o.zoomer.pan(+0.8));
            o.addCommand('zoomIn',   0, 'zoom in',       'add',        'narrow focus area duration', 2, 14, @(~,~)o.zoomer.zoom(0.8));
            o.addCommand('zoomOut',  0, 'zoom out',      'subtract',   'expand focus area duration', 3, 14, @(~,~)o.zoomer.zoom(1.25));
            o.addCommand('zoomReg',  0, 'zoom sel',      'z',          'zoom to selection',                2, 13, @o.zoomtoRegion);

            o.addCommandDesc('pantext1', 0, 'Edit dT',      1, 12);
            o.addCommand('deleteSapflow', me,  'delete dT data','d',          'delete selected sapflow data',         2, 11, @o.deleteSapflow);
            o.addCommand('interpolateSapflow', me,  'interpolate dT','i',          'interpolate selected sapflow data',    3, 11, @o.interpolateSapflow);
%            o.addCommand('addBreakpoint', me,  'add dT breakpoint','shift-b',          'add dT breakpoint',         3, 10, @o.addBreak);

            o.addCommandDesc('pantext2', 0, 'Edit dTmax Baseline',      1, 9);
            o.addCommand('delBla',   me, 'delete anchor points','delete',          'delete baseline anchors in range', 2, 8, @o.delBla);
            o.addCommand('anchorBla', me, 'set anchor points',     'a',          'anchor baseline to suggested points',  3, 8, @o.anchorBla);

            o.addCommandDesc('pantext3', 0, 'Automatic dTmax Baseline',      1, 7);
            o.addCommand('autoNightly', me,     'Nightly BL',     'shift-n',          'apply nightly baseline anchors',       2, 6, @o.autoNightlyBaseline);
            o.addCommand('auto', me,     'low-VPD BL',     'shift-a',          'apply automatic baseline anchors',       3, 6, @o.autoSetBaseline);

            o.addCommand('undo', me,    'undo last',     'control-z',          'undo last command',                    1, 6, @(~,~)o.sfp.undo());

%           Not currently used. For future revisions. 
%            o.addCommandDesc('pantext4', 0, 'Flag questionable K data',      1, 4);

            o.addCommand('prevSensor', 0, 'prev sensor',         'uparrow', 'prev sensor',      2, 1, @(~,~)o.selectSensor(-1));
            o.addCommand('nextSensor',  0, 'next sensor',         'downarrow',  'next sensor',       3, 1, @(~,~)o.selectSensor(1));


            o.addChartDesc('dTcharttxt', 0,...
                ['Blue line: dT data            ';
                 '                              ';
                 'Red line: dTmax baseline      ';
                 'Red o: dTmax anchor points    ';
                 '                              ';
                 'Green dot: Stable nighttime dT';
                 'Black dot: Stable dT & low VPD'],...
                    1, 11);
            o.addChartDesc('kcharttxt', 0,...
                ['Blue line: Initial K        ';
                 '     max nightly dT         ';
                 '                            ';
                 'Red line: Current K         ';
                 '     based on red line above';
                 '                            ';
                 'Green line: VPD (normalized)'],...
                    1, .5);
                       %TEMP!!! o.addCommand('addBla',   0, 'add BL anchor','b',          'add baseline anchors at cursor (b)', 0, 0, @o.addBla);

            % Specify all the plot lines we'll use.
            o.lines = struct();

            o.lines.sapflowAll = o.createEmptyLine('dtFull', 'b-');
            o.lines.sapflow    = o.createEmptyLine('dtZoom', 'b-');
            o.lines.spbl       = o.createEmptyLine('dtZoom', 'g.');
            o.lines.zvbl       = o.createEmptyLine('dtZoom', 'k.');
            o.lines.lzvbl      = o.createEmptyLine('dtZoom', 'k+');
            o.lines.blaAll     = o.createEmptyLine('dtFull', 'r-');
            o.lines.bla        = o.createEmptyLine('dtZoom', 'r-o');

            o.lines.kLineAll   = o.createEmptyLine('kFull',  'b-');
            o.lines.kLine      = o.createEmptyLine('kZoom',  'b-');
            o.lines.kaLineAll  = o.createEmptyLine('kFull',  'r--');
            o.lines.kaLine     = o.createEmptyLine('kZoom',  'r--');
            o.lines.nvpd       = o.createEmptyLine('kZoom',  'g-');

            o.selectBox        = o.createEmptyLine('dtZoom',  'k:');

            o.charts.dtZoom.ButtonDownFcn = @o.selectDtArea;

            ylabel(o.charts.dtZoom, 'dT editor');
            ylabel(o.charts.dtFull, 'dT overview');
            ylabel(o.charts.kZoom, 'K detail');
            ylabel(o.charts.kFull, 'K overview');

            for name = {'bla', 'sapflow', 'spbl', 'zvbl', 'lzvbl'}
                line = o.lines.(name{:});
                line.ButtonDownFcn = @o.markerClick;
                line.PickableParts = 'visible';
            end

            o.zoomer.createZoomAreaIndicators();

            o.projectConfig.numSensors = 0;
            
            o.show();
         end
         
    end

    methods (Access = private)

        function helpAbout(~, ~, ~)

            text = {
                'Baseliner 4.beta'
                ''
                'Created by A. Christopher Oishi & David Hawthorne'
                'USDA Forest Service, Southern Research Station'
                'Coweeta Hydrologic Laboratory'
                ' '
                'The Baseliner software has been made publicly available for research and'
                'publications. We encourage feedback and development by users to improve' 
                'the functionality and effectiveness of this product. Please acknowledge'
                'this software with the following citation: '
                '[ F.S. GTR and doi info ]'
                'and reference any relevant papers on the data processing methodology'
                '(e.g., Oishi et al. 2008). '
                ' '
                'We acknowledge Ram Oren and the C-H2O Ecology Lab group at the Nicholas'
                'School of the Environment at Duke University for development of Baseliner'
                'versions 1 through 3 where software development was supported by the'
                'Biological and Environmental Research (BER) Program, U.S. Department'
                'of Energy, through the Southeast Regional Center (SERC) of the National'
                'Institute for Global Envrironmental Change (NIGEC), and through the '
                'Terrestrial Carbon Process Program (TCP).'
                ' '
                'Copyright (c) 2015 Coweeta Hydrologic Laboratory US Forest Service'
                'Licensed under the Simplified BSD License'
            };
            msgbox(text, 'About Baseliner 4');
        end


        function saveProject(o, ~, ~)
            o.startWait('Saving');
            pfa = ProjectFileAccess();
            pfa.writeConfig(o.projectConfig)
            ns = o.projectConfig.numSensors;

            for i = 1:ns
                s = o.allSfp{i}.getModifications();

                o.updateWait(i/ns, 'Doing sensor %d', i);
                pfa.writeSensor(i, s);
            end
            o.updateWait(1,'Writing file');
            pfa.save(o.projectFilename);
            o.endWait();
        end

        function checkExit(o, ~, ~)
            if o.checkForUnsaved('exiting')
                delete(o.figureHnd);  % which stops the application
            end
        end

        function doAction = checkForUnsaved(o, action)

            if o.anyChangesMade()
                message = sprintf('Save all changes before %s?', action);
                action = questdlg(message, 'Unsaved changes','Save and continue','Don''t save changes', 'Cancel', 'Cancel');
                switch action(1)
                    case 'S'
                        o.saveProject(0,0);
                        doAction = 1;
                    case 'D'
                        doAction = 1;
                    case 'C'
                        doAction = 0;
                end
            else
                % no changes made
                doAction = 1;
            end
        end

        function saveAs(o, ~, ~)
            [filename, path] = uiputfile('*.xml', 'Select Project File');
            if not(filename)
                return
            end
            o.projectFilename = fullfile(path, filename);
            o.setWindowTitle('Sapflow Tool: %s', o.projectFilename)
            o.saveProject(0, 0)
        end


        function newProject(o, ~, ~)
            if not(o.checkForUnsaved('opening new project'))
                return;
            end
            [filename, path] = uiputfile('*.xml', 'Select Project File');
            if not(filename)
                return
            end
            [sourceFilename, sourcePath] = uigetfile('*.csv', 'Select Source Data File');
            if not(sourceFilename)
                return
            end

            sourceFilename = fullfile(sourcePath, sourceFilename);

            config = defaultConfig();
            config.sourceFilename = sourceFilename;
            config = projectDialog(config);

            if isstruct(config)
                o.projectConfig = config;
            else
                return
            end

            o.closeDownCurrent();

            o.startWait('Loading');

            o.readAndProcessSourceData({})

            o.endWait();

            if o.projectConfig.numSensors == 0
                %% Reading or processing the source file failed.
                return
            end

            o.projectFilename = fullfile(path, filename);
            o.setWindowTitle('Sapflow Tool: %s', o.projectFilename)

            o.saveProject(0, 0)
        end

        function closeDownCurrent(o)
            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).Visible = 'Off';
            end

            o.disableCommands({});
            o.zoomer.disable();
            o.disableChartsControl();

            o.deselect();
        end

        function openProject(o, ~, ~)
            if not(o.checkForUnsaved('opening another project'))
                return;
            end
            [filename, path] = uigetfile('*.xml', 'Select Project File');
            if not(filename)
                return
            end

            o.closeDownCurrent();

            o.startWait('Reading Config')

            o.projectFilename = fullfile(path, filename);
            o.setWindowTitle('Sapflow Tool: %s', o.projectFilename)
            try
                allConfig = loadSapflowConfig(o.projectFilename);
            catch err
                if strcmp(err.identifier, 'sapflowConfig:fileError')
                    errordlg(err.message, 'Project File Error')
                    o.endWait();
                    return
                else
                    rethrow(err);
                end
            end

            o.projectConfig = allConfig.project;

            o.readAndProcessSourceData(allConfig.sensors)

            o.endWait()
        end

        function export(o, ~, ~)
            % The user wants to export data from the tool.
            [filename, path] = uiputfile('*.csv', 'Select Export File');
            if not(filename)
                return
            end
            o.startWait('Exporting');
            kLines = zeros(o.allSfp{1}.ssL, o.projectConfig.numSensors);
            for i = 1:o.projectConfig.numSensors
                thisSfp = o.allSfp{i};
                kLines(:,i) = thisSfp.ka_line;
            end
            kOut=[ones(thisSfp.ssL,1) thisSfp.doy thisSfp.tod thisSfp.vpd thisSfp.par kLines];
            try
                csvwrite(fullfile(path, filename), kOut);
            catch err
                errordlg(err.message, 'Export failed')
            end

            o.endWait();
        end

        function export_nightly(o, ~, ~)
            % The user wants to export data from the tool.
            [filename, path] = uiputfile('*.csv', 'Select Export File');
            if not(filename)
                return
            end
            o.startWait('Exporting');
            kLines = zeros(o.allSfp{1}.ssL, o.projectConfig.numSensors);
            for i = 1:o.projectConfig.numSensors
                thisSfp = o.allSfp{i};
                thisSensor = o.allSfp{i}.ss';
                thisDOY = o.allSfp{i}.doy';
                thisTOD = o.allSfp{i}.tod';
                thisdTmax = BL_nightly(thisSensor,thisDOY,thisTOD);

                %  Modfied compute(o) function from SapflowProcessor.m
                % Based on the sapflow, bla and VPD data, calculate the K, KA
                % and NVPD values.
                %
                % If at least two bla points are positive ...
                if sum(thisSensor(thisdTmax)>0)>=2
                    thisblv = interp1(thisdTmax, thisSensor(thisdTmax), (1:length(thisSensor))');
                    thiska_line = thisblv ./ thisSensor - 1;
                    thiska_line(thiska_line < 0) = 0;
                else
                    thiska_line = nan * thisSensor;
                end
            
            
            kLines(:,i) = thiska_line;
            end
            kOut=[ones(thisSfp.ssL,1) thisSfp.doy thisSfp.tod thisSfp.vpd thisSfp.par kLines];
            try
                csvwrite(fullfile(path, filename), kOut);
            catch err
                errordlg(err.message, 'Export failed')
            end

            o.endWait();
        end

        function export_kerror(o, ~, ~)
            % The user wants to export estimate of error associated with alternate point selection of dTmax values.
            [filename, path] = uiputfile('*.csv', 'Select Export File');
            if not(filename)
                return
            end
            o.startWait('Exporting');

            kError = zeros(o.allSfp{1}.ssL, o.projectConfig.numSensors);

            for i = 1:o.projectConfig.numSensors
                thisSfp = o.allSfp{i};
                thisSensor = o.allSfp{i}.ss';
                thisbla = o.allSfp{i}.bla';
                if length(thisbla)>2
                    [mean_k, sd_k]=BL_rand(thisSensor,o.projectConfig.Timestep,thisbla);
                else
                   sd_k = zeros(o.allSfp{1}.ssL,1);
                end

                kError(:,i) = sd_k;
            end
            kOut=[ones(thisSfp.ssL,1) thisSfp.doy thisSfp.tod thisSfp.vpd thisSfp.par kError];
            try
                csvwrite(fullfile(path, filename), kOut);
            catch err
                errordlg(err.message, 'Export failed')
            end

            o.endWait();
        end

        function readAndProcessSourceData(o, sensorStates)
            % Attempt to extract data from the CSV files.
            % If there is a problem then projectConfig.numSensors is set to
            % zero.
            o.updateWait(0.1, 'Loading Source Data');
            try
                [~, par, vpd, sf, doy, tod] = loadRawSapflowData(o.projectConfig.sourceFilename);
            catch err
                errordlg(err.message, 'Load of raw sapflow data failed')
                o.projectConfig.numSensors = 0;
                return;
            end
            o.updateWait(0.2, 'Cleaning');

            o.updateWait(0.3, 'Processing PAR');
            par = processPar(par, tod);

            [~, o.projectConfig.numSensors] = size(sf);
            ns = o.projectConfig.numSensors;

            o.allSfp = cell(1, ns);

            for i = 1:o.projectConfig.numSensors
                o.updateWait(0.3 + 0.7 * i / ns , 'Building %d of %d', i, ns);

                thisSfp = SapflowProcessor(doy, tod, vpd, par, sf(:,i), o.projectConfig);
                thisSfp.baselineCallback = @o.baselineUpdated;
                thisSfp.sapflowCallback = @o.sapflowUpdated;
                thisSfp.undoCallback = @o.undoCallback;
                if length(sensorStates) >= i && isstruct(sensorStates{i})
                    thisSfp.setModifications(sensorStates{i})
                else
                    thisSfp.cleanRawData()
                end
                thisSfp.compute();

                o.allSfp{i} = thisSfp;
            end

            o.updateWait(1, 'Ready');

            o.sfpI = 1;
            o.sfp = o.allSfp{o.sfpI};

            o.zoomer.setXLimit([1, o.sfp.ssL]);

            o.setXData(1:o.sfp.ssL);

            o.selectSensor(0);
            o.zoomer.enable();
            o.enableChartsControl();

            for name = {'bla', 'blaAll', 'sapflowAll', 'sapflow', 'spbl', 'zvbl', 'lzvbl', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).Visible = 'On';
            end
        end

        function selectSensor(o, dir)
            % the joys of MATLAB's index from 1 approach ...
            indexFromZero = o.sfpI - 1;
            indexFromZero = mod(indexFromZero + dir, o.projectConfig.numSensors);
            o.sfpI = indexFromZero + 1;

            o.deselect();

            o.sfp = o.allSfp{o.sfpI};
            o.baselineUpdated();
            o.sapflowUpdated();

            o.reportStatus(sprintf('Sensor %d', o.sfpI));

            o.sfp.setup();

            o.enableCommands({'panLeft', 'panRight', 'zoomIn', 'zoomOut', 'nextSensor', 'prevSensor', 'auto','autoNightly'});

            o.zoomer.setYLimits({[0, max(o.sfp.ss)], [0, max(o.sfp.k_line)]});
        end

        function sapflowUpdated(o)
            % The SapflowProcessor calls this when sapflow is changed.
            %
            %TEMP!!! need to rethink/rename the sfp update callbacks
            o.lines.sapflowAll.YData = o.sfp.ss;
            o.lines.sapflow.YData = o.sfp.ss;

            o.lines.spbl.XData = o.sfp.spbl;
            o.lines.spbl.YData = o.sfp.ss(o.sfp.spbl);

            o.lines.zvbl.XData = o.sfp.zvbl;
            o.lines.zvbl.YData = o.sfp.ss(o.sfp.zvbl);

            o.lines.lzvbl.XData = o.sfp.lzvbl;
            o.lines.lzvbl.YData = o.sfp.ss(o.sfp.lzvbl);
        end

        function baselineUpdated(o)
            % Callback from SapflowProcessor
            o.lines.blaAll.XData = o.sfp.bla;
            o.lines.blaAll.YData = o.sfp.ss(o.sfp.bla);
            o.lines.bla.XData = o.sfp.bla;
            o.lines.bla.YData = o.sfp.ss(o.sfp.bla);

            o.lines.kLine.YData = o.sfp.k_line;
            o.lines.kLineAll.YData = o.sfp.k_line;
            o.lines.kaLine.YData = o.sfp.ka_line;
            o.lines.kaLineAll.YData = o.sfp.ka_line;
            o.lines.nvpd.YData = o.sfp.nvpd;
        end

        function delBla(o, ~, ~)
            % The user has clicked the delete baseline button.  Delete the
            % bla values in the selection range.
            o.deselect()
            i = o.pointsInSelection(o.lines.bla);
            o.sfp.delBaselineAnchors(i);
        end

        function i = pointsInSelection(o, line)
            % For the specified 1xN line, return a 1xN vector indicating
            % which points of that line fall within the X and Y values
            % bound by the selection rectangle.
            %
            % any NaN values in the X range are treated as in range.
            x = line.XData;
            y = line.YData;
            xr = o.selection.xRange;
            yr = o.selection.yRange;
            i = (x >= xr(1) & x <= xr(2) & y >= yr(1) & y <= yr(2));
            i = i | (isnan(y) & x >= xr(1) & x <= xr(2));  %capture NaN values  %TEMP!!! rethink
        end

        function deleteSapflow(o, ~, ~)
            % Delete all sapflow sample values inclosed in the selection
            % box.
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)', find(changes == -1)'];
            o.sfp.delSapflow(regions);
        end

        function interpolateSapflow(o, ~, ~)
            % Interpolate all sapflow sample values inclosed in the selection
            % box.
            o.deselect()
            i = o.pointsInSelection(o.lines.sapflow);
            changes = i - [0,i(1:end-1)];
            regions = [find(changes == 1)' - 1, find(changes == -1)'];
            o.sfp.interpolateSapflow(regions);
        end

        function zoomtoRegion(o, ~, ~)
            % Zoom in so the currently selected area fills the chart.
            o.deselect()
            o.zoomer.zoomToRange(1, o.selection.xRange, o.selection.yRange);
        end

        function anchorBla(o, ~, ~)
            % Anchor the baseline at every ZeroVpd candidate anchor point
            % in the selection box.
            o.deselect()
            i = o.pointsInSelection(o.lines.zvbl);
            o.sfp.addBaselineAnchors(o.lines.zvbl.XData(i));

        end

%   not currently used
%         function addBreak(o, ~, ~)
%             % .
%             o.deselect()
%             i = o.pointsInSelection(o.lines.zvbl);
%             o.sfp.addBaselineAnchors(o.lines.zvbl.XData(i));
% 
%         end

        function selectDtArea(o, chart, ~)
            % The user has clicked inside the zoom chart.  Once a range has
            % been selected by dragging the cursor mark this with the
            % selectBox line.  Enable any command that operates on selected
            % data.
            %
            % If the user clicks rather than drags AND the time the click
            % on has no valid sapflow data then the range without data is
            % selected.
            p1 = chart.CurrentPoint();
            rbbox();
            drawnow();  % gives next call enough time to register the mouse pointer has moved; sometimes it doesn't.
            p2 = chart.CurrentPoint();
            if p1 == p2
                % The user has clicked on an empty spot on the chart
                t = round(p1(1,1));

                % If there's no sapflow data at this time then try to place
                % the selection to bridge the NaN range.  And enable the
                % interpolate button so the user can join the dots.
                if isnan(o.sfp.ss(t))
                    notNan = not(isnan(o.sfp.ss));
                    tStart = find(notNan(1:t), 1, 'last');
                    tEnd = find(notNan(t:end), 1, 'first') + t - 1;
                    if tStart && tEnd
                        % There are valid sapflow data either side of the
                        % clicked point.
                        o.setSelectionArea([tStart, tEnd], o.sfp.ss([tStart, tEnd]));
                        o.enableCommands({'interpolateSapflow'});
                    end
                end
                return
            else
                % the user has dragged out a range
                o.setSelectionArea(sort([p1(1,1), p2(1,1)]), sort([p1(1,2), p2(1,2)]));
                o.enableCommands({'zoomReg', 'deleteSapflow', 'interpolateSapflow', 'delBla', 'anchorBla'});
            end
        end

        function markerClick(o, line, ~)
            % The user has clicked on the sapflow data line, or a baseline
            % candidate point.  Anchor the baseline to this point.
            chart = o.charts.dtZoom;
            ratio = chart.DataAspectRatio;
            p = chart.CurrentPoint();
            xr = chart.XLim;
            yr = chart.YLim;
            xd = line.XData;
            yd = line.YData;

            % Find the nearest point to where we clicked
            ii = find(xd > xr(1) & xd < xr(2) & yd > yr(1) & yd < yr(2));
            xp = p(1,1);
            yp = p(1,2);
            sqDist = ((xd(ii) - xp)/ratio(1)) .^ 2 + ((yd(ii) - yp)/ratio(2)) .^ 2;
            [~, i] = min(sqDist);

            o.sfp.addBaselineAnchors(xd(ii(i)));
        end

        function setXData(o, xData)
            % sets the common X axis values for all the 1 x ssL lines.
            for name = {'sapflowAll', 'sapflow', 'kLineAll', 'kLine', 'kaLineAll', 'kaLine', 'nvpd'}
                o.lines.(name{1}).XData = xData;
            end
        end

        function setSelectionArea(o,xRange, yRange)
            % Sets the selection range for susquent use and marks the area
            % on the zoomed chart.
            o.selection.xRange = xRange;
            o.selection.yRange = yRange;
            o.selectBox.XData = xRange([1, 2, 2, 1, 1]);
            o.selectBox.YData = yRange([1, 1, 2, 2, 1]);
            o.selectBox.Visible = 'On';
        end

        function deselect(o)
            % An action has been performed on the selected region.  We can
            % now clear the selection indicator and grey out the command
            % buttons.
            o.selectBox.Visible = 'Off';
            o.disableCommands({'zoomReg', 'deleteSapflow', 'interpolateSapflow', 'delBla', 'anchorBla'});
        end

        function undoCallback(o, description)
            % With each command executed or undone, we update the undo
            % button.  Either setting the button text to reflect the last
            % command or, if there are none, grey out the button.
            if not(description)
                o.renameCommand('undo', 'Undo');
                o.disableCommands({'undo'})
            else
                o.renameCommand('undo', strjoin({'Undo', description}));
                o.enableCommands({'undo'})
            end
        end

        function autoSetBaseline(o, ~, ~)
            o.startWait('Setting Baseline');
            o.sfp.auto();
            o.endWait();
        end

        function autoNightlyBaseline(o, ~, ~)
            o.startWait('Setting Baseline');
            o.sfp.autoNightly();
            o.endWait();
        end

        function isChange = anyChangesMade(o)
            % Checks if any sensor has had changes made to it.
            for i = 1:o.projectConfig.numSensors
                if o.allSfp{i}.changesMade();
                    isChange = 1;
                    return;
                end
            end
            isChange = 0;
        end
    end
end
