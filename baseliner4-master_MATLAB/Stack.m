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

classdef Stack < handle
    % A crude LIFO stack implementation.
    %
    % Supports the usual push() and pop().  Also peek() and empty().
    properties (Access = private)
        store % The 1 x N cell array used for the stack.
    end

    methods (Access = public)

        function o = Stack()
            % Constructs an empty stack.
            o.store = {};
        end

        function push(o, a)
            % Push to top
            o.store{end + 1} = a;
        end

        function a = pop(o)
            % Pop from top or die if empty.
            if isempty(o.store)
                error('Stack:pop', 'Tried popping from empty stack.');
            end
            a = o.store{end};
            o.store = o.store(1:end-1);
        end

        function a = peek(o)
            % Return from top of stack without popping.
            if isempty(o.store)
                error('Stack:peek', 'Tried peeking at empty stack.');
            end
            a = o.store{end};
        end

        function a = isEmpty(o)
            a = isempty(o.store);
        end


    end


end
